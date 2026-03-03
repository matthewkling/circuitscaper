#' Advanced Circuitscape Analysis
#'
#' Solve a single circuit with user-specified source and ground layers.
#'
#' @param resistance A [terra::SpatRaster] or file path. The resistance (or
#'   conductance) surface.
#' @param source A [terra::SpatRaster] or file path. Source current strengths
#'   (amps per cell). Cells with value 0 or NA are not sources.
#' @param ground A [terra::SpatRaster] or file path. Ground conductances
#'   (siemens per cell). Cells with value 0 or NA are not grounds.
#' @param resistance_is Character. Whether the resistance surface represents
#'   `"resistances"` (default) or `"conductances"`.
#' @param four_neighbors Logical. Use 4-neighbor (rook) connectivity instead of
#'   8-neighbor (queen). Default `FALSE`.
#' @param solver Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.
#' @param output_dir Optional character path. If provided, output files persist
#'   there. Default `NULL` uses a temporary directory.
#' @param verbose Logical. Print Circuitscape solver output. Default `FALSE`.
#'
#' @details
#' Unlike the other Circuitscape modes, advanced mode does not iterate over
#' focal nodes. Instead, the user provides explicit source current and ground
#' conductance rasters, and a single circuit is solved. This gives full control
#' over the current injection pattern and is useful for modeling specific
#' scenarios such as directional movement between a defined source area and
#' destination.
#'
#' @return A [terra::SpatRaster] with the following layers:
#' \describe{
#'   \item{cumulative_current}{Current density at each cell.}
#'   \item{voltage}{Voltage at each cell. Voltage is analogous to movement
#'     probability and decreases with distance from sources.}
#' }
#'
#' @references
#' Circuitscape user guide:
#' \url{https://docs.circuitscape.org/Circuitscape.jl/latest/usage/}
#'
#' @seealso [cs_pairwise()], [cs_one_to_all()], [cs_all_to_one()], [cs_setup()]
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
#' src <- rast(nrows = 10, ncols = 10, vals = 0)
#' src[1, 1] <- 1
#' gnd <- rast(nrows = 10, ncols = 10, vals = 0)
#' gnd[10, 10] <- 1
#' result <- cs_advanced(res, src, gnd)
#' plot(result)
#' plot(result[["voltage"]])
#' }
#'
#' @export
cs_advanced <- function(resistance,
                        source,
                        ground,
                        resistance_is = "resistances",
                        four_neighbors = FALSE,
                        solver = "cg+amg",
                        output_dir = NULL,
                        verbose = FALSE) {

  ensure_julia()

  # Validate arguments
  match.arg(resistance_is, c("resistances", "conductances"))
  match.arg(solver, c("cg+amg", "cholmod"))

  # Set up working directory
  use_temp <- is.null(output_dir)
  work_dir <- if (use_temp) tempfile("cs_") else output_dir
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  if (use_temp) on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  # Capture CRS
  input_crs <- get_input_crs(resistance)

  # Validate matching extents
  if (inherits(resistance, "SpatRaster") && inherits(source, "SpatRaster")) {
    validate_raster_match(resistance, source, "resistance", "source")
  }
  if (inherits(resistance, "SpatRaster") && inherits(ground, "SpatRaster")) {
    validate_raster_match(resistance, ground, "resistance", "ground")
  }

  # Write inputs to ASC
  res_path <- ensure_asc(resistance, work_dir, "resistance")
  src_path <- ensure_asc(source, work_dir, "source")
  gnd_path <- ensure_asc(ground, work_dir, "ground")

  # Build INI configuration
  prefix <- "cs_output"
  ini_path <- build_cs_config(
    mode = "advanced",
    resistance_file = res_path,
    output_dir = work_dir,
    output_prefix = prefix,
    source_file = src_path,
    ground_file = gnd_path,
    resistance_is = resistance_is,
    four_neighbors = four_neighbors,
    solver = solver,
    write_voltage = TRUE
  )

  # Run Circuitscape
  if (verbose) {
    JuliaCall::julia_call("Circuitscape.compute", ini_path)
  } else {
    JuliaCall::julia_eval(
      paste0('redirect_stdout(devnull) do; redirect_stderr(devnull) do; ',
             'Circuitscape.compute("', gsub("\\\\", "/", ini_path), '"); ',
             'end; end')
    )
  }

  # Parse and return output rasters
  parse_cs_output(work_dir, prefix, input_crs)
}
