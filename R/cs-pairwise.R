#' Pairwise Circuitscape Analysis
#'
#' Compute effective resistance and cumulative current flow between all pairs of
#' focal nodes using Circuitscape's pairwise mode.
#'
#' @param resistance A [terra::SpatRaster] or file path. The resistance (or
#'   conductance) surface.
#' @param locations A [terra::SpatRaster] or file path. Focal nodes/regions
#'   raster with integer IDs.
#' @param resistance_is Character. Whether the resistance surface represents
#'   `"resistances"` (default) or `"conductances"`.
#' @param four_neighbors Logical. Use 4-neighbor (rook) connectivity instead of
#'   8-neighbor (queen). Default `FALSE`.
#' @param solver Character. Solver to use: `"cg+amg"` (default) or `"cholmod"`.
#' @param output_dir Optional character path. If provided, output files persist
#'   there. Default `NULL` uses a temporary directory that is cleaned up
#'   automatically.
#' @param verbose Logical. Print Circuitscape solver output. Default `FALSE`.
#'
#' @return A named list with:
#' \describe{
#'   \item{current_map}{A [terra::SpatRaster] with named layers for each output
#'     map (e.g., `"cumulative_current"`).}
#'   \item{resistance_matrix}{A numeric matrix of pairwise effective
#'     resistances.}
#' }
#'
#' @references
#' Circuitscape user guide:
#' \url{https://docs.circuitscape.org/Circuitscape.jl/latest/usage/}
#'
#' @seealso [cs_one_to_all()], [cs_all_to_one()], [cs_advanced()], [cs_setup()]
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
#' locs <- rast(nrows = 10, ncols = 10, vals = 0)
#' locs[1, 1] <- 1; locs[1, 10] <- 2; locs[10, 5] <- 3
#' result <- cs_pairwise(res, locs)
#' plot(result$current_map)
#' result$resistance_matrix
#' }
#'
#' @export
cs_pairwise <- function(resistance,
                        locations,
                        resistance_is = "resistances",
                        four_neighbors = FALSE,
                        solver = "cg+amg",
                        output_dir = NULL,
                        verbose = FALSE) {

  run_cs_mode("pairwise",
              resistance = resistance,
              locations = locations,
              resistance_is = resistance_is,
              four_neighbors = four_neighbors,
              solver = solver,
              output_dir = output_dir,
              verbose = verbose)
}


#' Run a Circuitscape Focal-Node Mode
#'
#' Internal workhorse for pairwise, one-to-all, and all-to-one modes.
#'
#' @param mode Character. The Circuitscape scenario.
#' @param resistance,locations,resistance_is,four_neighbors,solver,output_dir,verbose
#'   See [cs_pairwise()] for details.
#' @return For pairwise mode, a named list with `$current_map` and
#'   `$resistance_matrix`. For one-to-all and all-to-one, just the SpatRaster.
#' @noRd
run_cs_mode <- function(mode,
                        resistance,
                        locations,
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

  # Capture CRS before writing to ASC
  input_crs <- get_input_crs(resistance)

  # Validate matching extents if both are SpatRasters
  if (inherits(resistance, "SpatRaster") && inherits(locations, "SpatRaster")) {
    validate_raster_match(resistance, locations, "resistance", "locations")
  }

  # Write inputs to ASC
  res_path <- ensure_asc(resistance, work_dir, "resistance")
  loc_path <- ensure_asc(locations, work_dir, "locations")

  # Build INI configuration
  prefix <- "cs_output"
  ini_path <- build_cs_config(
    mode = mode,
    resistance_file = res_path,
    output_dir = work_dir,
    output_prefix = prefix,
    locations_file = loc_path,
    resistance_is = resistance_is,
    four_neighbors = four_neighbors,
    solver = solver
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

  # Parse outputs
  current_map <- parse_cs_output(work_dir, prefix, input_crs)

  if (mode == "pairwise") {
    resistance_matrix <- read_resistance_matrix(work_dir, prefix)
    list(
      current_map = current_map,
      resistance_matrix = resistance_matrix
    )
  } else {
    current_map
  }
}
