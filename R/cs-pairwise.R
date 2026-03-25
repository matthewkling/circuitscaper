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
#'   * A [terra::SpatRaster] (or `raster::RasterLayer`) with positive integer IDs
#'     identifying each node. Cells with value 0 or `NA` are not treated as focal
#'     nodes.
#'   * A file path to a raster file (e.g., `.tif`, `.asc`).
#'   * A two-column matrix or data.frame of x/y coordinates. Each row becomes
#'     a focal node, auto-assigned IDs 1, 2, 3, ... in row order. Coordinates
#'     are snapped to the nearest cell of the `resistance` raster.
#' @param resistance_is Character. Whether the resistance surface represents
#'   `"resistances"` (default) or `"conductances"`.
#' @param four_neighbors Logical. Use 4-neighbor (rook) connectivity instead of
#'   8-neighbor (queen). Default `FALSE`.
#' @param avg_resistances Logical. When using 8-neighbor connectivity, compute
#'   the resistance of diagonal connections as the average of the two cells
#'   rather than their sum. Default `FALSE` (Circuitscape default). Ignored when
#'   `four_neighbors = TRUE`.
#' @param short_circuit Optional [terra::SpatRaster] or file path. Raster
#'   identifying short-circuit regions (aka polygons). Cells sharing the same
#'   positive integer value are treated as short-circuit regions with zero
#'   resistance between them. Default `NULL` (no short-circuit regions).
#' @param included_pairs Optional character file path. A text file specifying
#'   which pairs of focal nodes to include or exclude from analysis. See the
#'   Circuitscape documentation for the file format. Default `NULL` (all pairs).
#' @param write_voltage Logical. Write voltage maps. Default `FALSE`. When
#'   `TRUE`, per-iteration voltage layers (named `voltage_1`, `voltage_2`, ...)
#'   are included in the output raster.
#' @param cumulative_only Logical. If `TRUE` (default), only the cumulative
#'   current map is returned. If `FALSE`, per-iteration current layers (named
#'   `current_1`, `current_2`, ...) are also included. Use with caution for
#'   large numbers of focal nodes, as this can produce many layers.
#' @param source_strengths Optional. Variable current injection strengths for
#'   each focal node. Can be:
#'   * A numeric vector with one value per focal node (in the same order as the
#'     locations input). Node IDs are assigned 1, 2, 3, ... matching the order.
#'   * A character file path to a tab-delimited text file with two columns:
#'     node ID and strength in amps. Nodes not listed default to 1 amp.
#'   Default `NULL` (all nodes inject 1 amp).
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
#'   \item{current_map}{A [terra::SpatRaster]. By default contains a single
#'     `cumulative_current` layer (current flow summed across all pairs). When
#'     `cumulative_only = FALSE`, additional per-pair layers are included
#'     (e.g., `current_1_2`, `current_1_3`). When `write_voltage = TRUE`,
#'     per-pair voltage layers are included (e.g., `voltage_1_2`,
#'     `voltage_1_3`).}
#'   \item{resistance_matrix}{A symmetric numeric matrix of pairwise effective
#'     resistances between focal nodes, with node IDs as row and column names.}
#' }
#'
#' @references
#' McRae, B.H. (2006). Isolation by resistance. \emph{Evolution}, 60(8),
#' 1551--1561. \doi{10.1111/j.1558-5646.2006.tb00500.x}
#'
#' Circuitscape.jl: \url{https://docs.circuitscape.org/Circuitscape.jl/latest/}
#'
#' @seealso [cs_one_to_all()], [cs_all_to_one()], [cs_advanced()], [cs_setup()]
#'
#' @examplesIf circuitscaper:::julia_check()
#' library(terra)
#' res <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
#' coords <- matrix(c(10, 40, 40, 40, 10, 10, 40, 10), ncol = 2, byrow = TRUE)
#' result <- cs_pairwise(res, coords, cumulative_only = FALSE)
#' plot(result$current_map)
#' result$resistance_matrix
#'
#' @export
cs_pairwise <- function(resistance,
                        locations,
                        resistance_is = "resistances",
                        four_neighbors = FALSE,
                        avg_resistances = FALSE,
                        short_circuit = NULL,
                        included_pairs = NULL,
                        write_voltage = FALSE,
                        cumulative_only = TRUE,
                        source_strengths = NULL,
                        solver = "cg+amg",
                        output_dir = NULL,
                        verbose = FALSE) {

  run_cs_mode("pairwise",
              resistance = resistance,
              locations = locations,
              resistance_is = resistance_is,
              four_neighbors = four_neighbors,
              avg_resistances = avg_resistances,
              short_circuit = short_circuit,
              included_pairs = included_pairs,
              write_voltage = write_voltage,
              cumulative_only = cumulative_only,
              source_strengths = source_strengths,
              solver = solver,
              output_dir = output_dir,
              verbose = verbose)
}


#' Run a Circuitscape Focal-Node Mode
#'
#' Internal workhorse for pairwise, one-to-all, and all-to-one modes.
#'
#' @param mode Character. The Circuitscape scenario.
#' @param resistance,locations,resistance_is,four_neighbors,avg_resistances,solver,output_dir,verbose,short_circuit,included_pairs,source_strengths
#'   See [cs_pairwise()] for details.
#' @return For pairwise mode, a named list with `$current_map` and
#'   `$resistance_matrix`. For one-to-all and all-to-one, just the SpatRaster.
#' @noRd
run_cs_mode <- function(mode,
                        resistance,
                        locations,
                        resistance_is = "resistances",
                        four_neighbors = FALSE,
                        avg_resistances = FALSE,
                        short_circuit = NULL,
                        included_pairs = NULL,
                        write_voltage = FALSE,
                        cumulative_only = TRUE,
                        source_strengths = NULL,
                        solver = "cg+amg",
                        output_dir = NULL,
                        verbose = FALSE) {

  ensure_julia()

  # Validate arguments
  match.arg(resistance_is, c("resistances", "conductances"))
  match.arg(solver, c("cg+amg", "cholmod"))
  validate_resistance_values(resistance, resistance_is)

  # Set up working directory
  use_temp <- is.null(output_dir)
  work_dir <- if (use_temp) tempfile("cs_") else output_dir
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  if (use_temp) on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  # Convert RasterLayer to SpatRaster if applicable
  if (inherits(resistance, "RasterLayer")) {
    resistance <- terra::rast(resistance)
  }

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

  sc_path <- NULL
  if (!is.null(short_circuit)) {
    if (inherits(resistance, "SpatRaster") &&
        inherits(short_circuit, "SpatRaster")) {
      validate_raster_match(resistance, short_circuit,
                            "resistance", "short_circuit")
    }
    sc_path <- ensure_asc(short_circuit, work_dir, "short_circuit")
  }

  # Handle variable source strengths
  vs_path <- NULL
  if (!is.null(source_strengths)) {
    if (is.character(source_strengths)) {
      # File path passthrough
      if (!file.exists(source_strengths)) {
        stop("source_strengths file not found: ", source_strengths,
             call. = FALSE)
      }
      vs_path <- normalizePath(source_strengths, mustWork = TRUE)
    } else if (is.numeric(source_strengths)) {
      # Numeric vector — determine node count and validate
      n_nodes <- count_focal_nodes(locations, loc_path)
      if (length(source_strengths) != n_nodes) {
        stop("source_strengths has length ", length(source_strengths),
             " but there are ", n_nodes, " focal nodes.", call. = FALSE)
      }
      if (any(is.na(source_strengths))) {
        stop("source_strengths must not contain NA values.", call. = FALSE)
      }
      # Write tab-delimited strengths file
      vs_path <- file.path(work_dir, "source_strengths.txt")
      write_source_strengths(source_strengths, vs_path)
    } else {
      stop("source_strengths must be a numeric vector or a file path.",
           call. = FALSE)
    }
  }

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
    avg_resistances = avg_resistances,
    short_circuit_file = sc_path,
    included_pairs_file = included_pairs,
    solver = solver,
    write_voltage = write_voltage,
    cumulative_only = cumulative_only,
    variable_source_file = vs_path
  )

  # Run Circuitscape
  julia_expr <- paste0(
    'Circuitscape.compute("', gsub("\\\\", "/", ini_path), '")'
  )
  run_julia(julia_expr, verbose = verbose)

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
