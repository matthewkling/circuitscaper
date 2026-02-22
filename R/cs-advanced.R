#' Advanced Circuitscape Analysis
#'
#' Advanced mode with user-specified source and ground layers. Unlike the other
#' modes, there is no focal node concept — the user provides explicit source
#' current strengths and ground conductances.
#'
#' @param resistance A [terra::SpatRaster] or file path. The resistance (or
#'   conductance) surface.
#' @param source A [terra::SpatRaster] or file path. Source current strengths.
#' @param ground A [terra::SpatRaster] or file path. Ground conductances.
#' @param resistance_is Character. Whether the resistance surface represents
#'   `"resistances"` (default) or `"conductances"`.
#' @param four_neighbors Logical. Use 4-neighbor (rook) connectivity instead of
#'   8-neighbor (queen). Default `FALSE`.
#' @param solver Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.
#' @param write_voltage Logical. Also compute voltage maps. Default `FALSE`.
#' @param output_dir Optional character path. If provided, output files persist
#'   there. Default `NULL` uses a temporary directory.
#' @param verbose Logical. Print Circuitscape solver output. Default `FALSE`.
#'
#' @return A [terra::SpatRaster] with named layers. Always includes
#'   `"cumulative_current"`. If `write_voltage = TRUE`, also includes
#'   `"voltage"`.
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
#'
#' # With voltage maps
#' result_v <- cs_advanced(res, src, gnd, write_voltage = TRUE)
#' plot(result_v[["voltage"]])
#' }
#'
#' @export
cs_advanced <- function(resistance,
                        source,
                        ground,
                        resistance_is = "resistances",
                        four_neighbors = FALSE,
                        solver = "cg+amg",
                        write_voltage = FALSE,
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
    write_voltage = write_voltage
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
