#' Run Omniscape Moving-Window Connectivity Analysis
#'
#' Performs an Omniscape analysis, computing omnidirectional landscape
#' connectivity using a moving window approach based on circuit theory.
#'
#' @param resistance A [terra::SpatRaster] or file path. The resistance (or
#'   conductance) surface. Higher values represent greater resistance to
#'   movement.
#' @param radius Numeric. Moving window radius in pixels. This determines the
#'   maximum distance over which connectivity is evaluated from each source
#'   pixel.
#' @param source_strength Optional [terra::SpatRaster] or file path. Source
#'   strength weights, often derived from habitat quality or suitability, where
#'   higher values indicate stronger sources of movement. If `NULL` (default),
#'   source strength is set to the inverse of resistance (i.e., all non-nodata
#'   pixels become sources, weighted by conductance). Use `r_cutoff` to exclude
#'   high-resistance cells from acting as sources in that case.
#' @param block_size Integer. Aggregation block size for source points. Default
#'   `1` (no aggregation). A `block_size` of e.g. 3 coarsens the source grid
#'   into 3x3 blocks, reducing the number of solves (and thus computation time)
#'   substantially with typically negligible effects on results.
#' @param source_threshold Numeric. Minimum source strength to include a pixel.
#'   Default `0`.
#' @param r_cutoff Numeric. Maximum resistance value for a cell to be included
#'   as a source when `source_strength = NULL`. Cells with resistance above
#'   this value are excluded as sources. Default `Inf` (no cutoff). Only
#'   relevant when `source_strength` is not provided.
#' @param resistance_is Character. Whether the resistance surface represents
#'   `"resistances"` (default) or `"conductances"`.
#' @param calc_normalized_current Logical. Compute normalized current flow.
#'   Default `TRUE`.
#' @param calc_flow_potential Logical. Compute flow potential. Default `TRUE`.
#' @param condition Optional [terra::SpatRaster] or file path. Conditional layer
#'   for targeted connectivity analysis.
#' @param condition_type Character. How the condition layer filters connectivity:
#'   `"within"` (connectivity only between source and target cells whose
#'   condition values fall within a specified range) or `"equal"` (connectivity
#'   only between cells with equal condition values, evaluated pairwise). Only
#'   relevant if `condition` is provided. Note: `"within"` currently uses
#'   Omniscape's default unbounded range (`-Inf` to `Inf`), which effectively
#'   includes all cells. Finer control over range bounds is planned for a
#'   future version.
#' @param parallelize Logical. Use Julia multithreading. Default `FALSE`.
#'   Julia's thread count is fixed at startup. If Julia was already initialized
#'   without enough threads, a warning is issued. To avoid this, call
#'   [cs_setup()] with the `threads` argument at the start of your session.
#' @param julia_threads Integer. Number of Julia threads if `parallelize =
#'   TRUE`. Default `2`. Ignored if Julia is already running with fewer threads.
#' @param solver Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.
#' @param output_dir Optional character path. If provided, output files persist
#'   there. Default `NULL` uses a temporary directory.
#' @param verbose Logical. Print Omniscape output. Default `FALSE`.
#'
#' @return A [terra::SpatRaster] with the following layers (depending on
#'   options):
#' \describe{
#'   \item{cumulative_current}{Raw cumulative current flow. Always present.
#'     Higher values indicate cells that carry more current across all
#'     moving-window iterations.}
#'   \item{flow_potential}{Expected current under homogeneous resistance
#'     (if `calc_flow_potential = TRUE`). Reflects the spatial configuration
#'     of sources independently of landscape resistance.}
#'   \item{normalized_current}{Cumulative current divided by flow potential
#'     (if `calc_normalized_current = TRUE`). Values greater than 1 indicate
#'     cells where connectivity is higher than expected given the source
#'     geometry; values less than 1 indicate relative barriers. This is
#'     typically the most informative layer for identifying corridors and
#'     pinch points.}
#' }
#'
#' @references
#' Landau, V.A., Shah, V.B., Anantharaman, R. & Hall, K.R. (2021).
#' Omniscape.jl: Software to compute omnidirectional landscape connectivity.
#' \emph{Journal of Open Source Software}, 6(57), 2829.
#' \doi{10.21105/joss.02829}
#'
#' Omniscape.jl: \url{https://docs.circuitscape.org/Omniscape.jl/latest/}
#'
#' @seealso [cs_pairwise()], [cs_setup()]
#'
#' @examplesIf circuitscaper:::julia_check()
#' library(terra)
#' res <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
#' result <- os_run(res, radius = 20)
#' plot(result)
#'
#' @export
os_run <- function(resistance,
                   radius,
                   source_strength = NULL,
                   block_size = 1L,
                   source_threshold = 0,
                   r_cutoff = Inf,
                   resistance_is = "resistances",
                   calc_normalized_current = TRUE,
                   calc_flow_potential = TRUE,
                   condition = NULL,
                   condition_type = NULL,
                   parallelize = FALSE,
                   julia_threads = 2L,
                   solver = "cg+amg",
                   output_dir = NULL,
                   verbose = FALSE) {

  # Handle threading before Julia init
  if (parallelize && !.cs_env$julia_ready) {
    Sys.setenv(JULIA_NUM_THREADS = paste0(julia_threads, ",0"))
    .cs_env$julia_threads <- as.integer(julia_threads)
  } else if (parallelize && .cs_env$julia_ready &&
             .cs_env$julia_threads < julia_threads) {
    warning(
      "Julia is already running with ", .cs_env$julia_threads, " thread(s). ",
      "Cannot change to ", julia_threads, " threads mid-session. ",
      "To use multithreading, restart R and call cs_setup(threads = ",
      julia_threads, ") before any other circuitscaper functions.",
      call. = FALSE
    )
  }

  ensure_julia()

  # Validate arguments
  match.arg(resistance_is, c("resistances", "conductances"))
  match.arg(solver, c("cg+amg", "cholmod"))
  if (!is.null(condition_type)) {
    condition_type <- match.arg(condition_type, c("within", "equal"))
  }
  validate_resistance_values(resistance, resistance_is)

  # Set up working directory
  use_temp <- is.null(output_dir)
  work_dir <- if (use_temp) tempfile("os_") else output_dir
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  if (use_temp) on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  # Capture CRS
  input_crs <- get_input_crs(resistance)

  # Write inputs to ASC
  res_path <- ensure_asc(resistance, work_dir, "resistance")

  src_path <- NULL
  if (!is.null(source_strength)) {
    if (inherits(resistance, "SpatRaster") &&
        inherits(source_strength, "SpatRaster")) {
      validate_raster_match(resistance, source_strength,
                            "resistance", "source_strength")
    }
    src_path <- ensure_asc(source_strength, work_dir, "source_strength")
  }

  cond_path <- NULL
  if (!is.null(condition)) {
    if (inherits(resistance, "SpatRaster") &&
        inherits(condition, "SpatRaster")) {
      validate_raster_match(resistance, condition, "resistance", "condition")
    }
    cond_path <- ensure_asc(condition, work_dir, "condition")
  }

  # Build INI configuration
  ini_path <- build_os_config(
    resistance_file = res_path,
    radius = radius,
    output_dir = work_dir,
    source_file = src_path,
    block_size = block_size,
    source_threshold = source_threshold,
    r_cutoff = r_cutoff,
    resistance_is = resistance_is,
    calc_normalized_current = calc_normalized_current,
    calc_flow_potential = calc_flow_potential,
    condition_file = cond_path,
    condition_type = condition_type,
    parallelize = parallelize,
    julia_threads = julia_threads,
    solver = solver
  )

  # Run Omniscape
  julia_expr <- paste0(
    'Omniscape.run_omniscape("', gsub("\\\\", "/", ini_path), '")'
  )
  run_julia(julia_expr, verbose = verbose)

  # Parse and return output rasters from the Omniscape output subdirectory
  os_output_dir <- file.path(work_dir, "omniscape_output")
  parse_os_output(os_output_dir, input_crs)
}
