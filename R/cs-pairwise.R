#' Pairwise Circuitscape Analysis
#'
#' Compute pairwise effective resistances and cumulative current flow between
#' all pairs of focal nodes.
#'
#' @param resistance A [terra::SpatRaster] or file path. The resistance (or
#'   conductance) surface. Higher values represent greater resistance to
#'   movement. Use the `resistance_is` argument if your surface represents
#'   conductances instead.
#' @param locations Focal node locations, provided as any of:
#'   * A [terra::SpatRaster] with positive integer IDs identifying each node.
#'     Cells with value 0 or `NA` are not treated as focal nodes.
#'   * A file path to a raster file (e.g., `.tif`, `.asc`).
#'   * A two-column matrix or data.frame of x/y coordinates. Each row becomes
#'     a focal node, auto-assigned IDs 1, 2, 3, ... in row order. Coordinates
#'     are snapped to the nearest cell of the `resistance` raster. See
#'     [cs_locations()].
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
#' @details
#' Pairwise mode iterates over every unique pair of focal nodes. For each pair,
#' one node is injected with 1 amp of current and the other is connected to
#' ground. The effective resistance between the pair is recorded, and the
#' resulting current flow is accumulated across all pairs into a cumulative
#' current map that highlights important movement corridors.
#'
#' This is the most common Circuitscape mode and is typically used to quantify
#' connectivity between discrete habitat patches or populations. The resistance
#' matrix can be used as a distance metric in analyses such as isolation by
#' resistance.
#'
#' @return A named list with:
#' \describe{
#'   \item{current_map}{A [terra::SpatRaster] with a single layer:
#'     \describe{
#'       \item{cumulative_current}{Current flow summed across all pairs,
#'         indicating the relative importance of each cell as a movement
#'         corridor.}
#'     }
#'   }
#'   \item{resistance_matrix}{A symmetric numeric matrix of pairwise effective
#'     resistances between focal nodes, with node IDs as row and column names.}
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
#' coords <- matrix(c(-140, 70, -60, 70, -100, 30), ncol = 2, byrow = TRUE)
#' result <- cs_pairwise(res, coords)
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

  # Convert coordinate input to raster
  if (is.matrix(locations) || is.data.frame(locations)) {
    locations <- cs_locations(locations, resistance)
  }

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
