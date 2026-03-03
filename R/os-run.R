#' Run Omniscape Moving-Window Connectivity Analysis
#'
#' Performs an Omniscape analysis, computing omnidirectional landscape
#' connectivity using a moving window approach based on circuit theory.
#'
#' @param resistance A [terra::SpatRaster] or file path. The resistance (or
#'   conductance) surface.
#' @param radius Numeric. Moving window radius in pixels.
#' @param source_strength Optional [terra::SpatRaster] or file path. Source
#'   strength weights. If `NULL` (default), all non-nodata pixels are treated as
#'   sources with equal weight.
#' @param block_size Integer. Aggregation block size for source points. Default
#'   `1` (no aggregation). Increasing this significantly speeds computation.
#' @param source_threshold Numeric. Minimum source strength to include a pixel.
#'   Default `0`.
#' @param resistance_is Character. Whether the resistance surface represents
#'   `"resistances"` (default) or `"conductances"`.
#' @param calc_normalized_current Logical. Compute normalized current flow.
#'   Default `TRUE`.
#' @param calc_flow_potential Logical. Compute flow potential. Default `TRUE`.
#' @param condition Optional [terra::SpatRaster] or file path. Conditional layer
#'   for targeted connectivity analysis.
#' @param condition_type Character. Determines how the condition layer is used.
#'   Only relevant if `condition` is provided. See the Omniscape documentation
#'   for options.
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
#' @return A [terra::SpatRaster] with named layers. Possible layers depending on
#'   options:
#' \describe{
#'   \item{cumulative_current}{Cumulative current flow.}
#'   \item{flow_potential}{Flow potential (if `calc_flow_potential = TRUE`).}
#'   \item{normalized_current}{Normalized current flow (if
#'     `calc_normalized_current = TRUE`).}
#' }
#'
#' @references
#' Omniscape documentation:
#' \url{https://docs.circuitscape.org/Omniscape.jl/latest/}
#'
#' @seealso [os_compare()], [cs_pairwise()], [cs_setup()]
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 50, ncols = 50, vals = runif(2500, 1, 10))
#' result <- os_run(res, radius = 10)
#' plot(result)
#' plot(result[["normalized_current"]])
#' }
#'
#' @export
os_run <- function(resistance,
                   radius,
                   source_strength = NULL,
                   block_size = 1L,
                   source_threshold = 0,
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
    Sys.setenv(JULIA_NUM_THREADS = as.character(julia_threads))
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
  if (verbose) {
    JuliaCall::julia_call("Omniscape.run_omniscape", ini_path)
  } else {
    JuliaCall::julia_eval(
      paste0('redirect_stdout(devnull) do; redirect_stderr(devnull) do; ',
             'Omniscape.run_omniscape("', gsub("\\\\", "/", ini_path), '"); ',
             'end; end')
    )
  }

  # Parse and return output rasters from the Omniscape output subdirectory
  os_output_dir <- file.path(work_dir, "omniscape_output")
  parse_os_output(os_output_dir, input_crs)
}
