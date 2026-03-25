#' Advanced Circuitscape Analysis
#'
#' Solve a single circuit with user-specified source and ground layers.
#'
#' @param resistance A [terra::SpatRaster] or file path. The resistance (or
#'   conductance) surface. Higher values represent greater resistance to
#'   movement.
#' @param source A [terra::SpatRaster] or file path. Source current strengths
#'   (amps per cell). Cells with value 0 or NA are not sources.
#' @param ground A [terra::SpatRaster] or file path. Ground node values.
#'   Interpretation depends on `ground_is`: resistances to ground (default)
#'   or conductances to ground. Cells with value 0 or NA are not grounds.
#' @param resistance_is Character. Whether the resistance surface represents
#'   `"resistances"` (default) or `"conductances"`.
#' @param ground_is Character. Whether the ground raster values represent
#'   `"resistances"` (default) or `"conductances"` to ground.
#' @param use_unit_currents Logical. If `TRUE`, all current sources are set to
#'   1 amp regardless of the values in the source raster. Default `FALSE`.
#' @param use_direct_grounds Logical. If `TRUE`, all ground nodes are tied
#'   directly to ground (zero resistance), regardless of the values in the
#'   ground raster. Default `FALSE`.
#' @param short_circuit Optional [terra::SpatRaster] or file path. Raster
#'   identifying short-circuit regions (aka polygons). Cells sharing the same
#'   positive integer value are treated as short-circuit regions with zero
#'   resistance between them. Default `NULL` (no short-circuit regions).
#' @param source_ground_conflict Character. How to resolve cells that appear in
#'   both the source and ground rasters: `"keepall"` (default, keep both),
#'   `"rmvsrc"` (remove source), `"rmvgnd"` (remove ground), or `"rmvall"`
#'   (remove both).
#' @param four_neighbors Logical. Use 4-neighbor (rook) connectivity instead of
#'   8-neighbor (queen). Default `FALSE`.
#' @param avg_resistances Logical. When using 8-neighbor connectivity, compute
#'   the resistance of diagonal connections as the average of the two cells
#'   rather than their sum. Default `FALSE` (Circuitscape default). Ignored when
#'   `four_neighbors = TRUE`.
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
#'   \item{current}{Current density at each cell.}
#'   \item{voltage}{Voltage at each cell. Voltage is analogous to movement
#'     probability and decreases with distance from sources.}
#' }
#'
#' @references
#' McRae, B.H. (2006). Isolation by resistance. \emph{Evolution}, 60(8),
#' 1551--1561. \doi{10.1111/j.1558-5646.2006.tb00500.x}
#'
#' Circuitscape.jl: \url{https://docs.circuitscape.org/Circuitscape.jl/latest/}
#'
#' @seealso [cs_pairwise()], [cs_one_to_all()], [cs_all_to_one()], [cs_setup()]
#'
#' @examplesIf nchar(Sys.which("julia")) > 0
#' library(terra)
#' res <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
#' origin <- rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' dest <- rast(system.file("extdata/ground.tif", package = "circuitscaper"))
#' result <- cs_advanced(res, origin, dest, ground_is = "conductances")
#' plot(result)
#'
#' @export
cs_advanced <- function(resistance,
                        source,
                        ground,
                        resistance_is = "resistances",
                        ground_is = "resistances",
                        use_unit_currents = FALSE,
                        use_direct_grounds = FALSE,
                        short_circuit = NULL,
                        source_ground_conflict = "keepall",
                        four_neighbors = FALSE,
                        avg_resistances = FALSE,
                        solver = "cg+amg",
                        output_dir = NULL,
                        verbose = FALSE) {

  ensure_julia()

  # Validate arguments
  match.arg(resistance_is, c("resistances", "conductances"))
  match.arg(ground_is, c("resistances", "conductances"))
  match.arg(source_ground_conflict,
            c("keepall", "rmvsrc", "rmvgnd", "rmvall"))
  match.arg(solver, c("cg+amg", "cholmod"))
  validate_resistance_values(resistance, resistance_is)

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

  sc_path <- NULL
  if (!is.null(short_circuit)) {
    if (inherits(resistance, "SpatRaster") &&
        inherits(short_circuit, "SpatRaster")) {
      validate_raster_match(resistance, short_circuit,
                            "resistance", "short_circuit")
    }
    sc_path <- ensure_asc(short_circuit, work_dir, "short_circuit")
  }

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
    ground_is = ground_is,
    use_unit_currents = use_unit_currents,
    use_direct_grounds = use_direct_grounds,
    short_circuit_file = sc_path,
    source_ground_conflict = source_ground_conflict,
    four_neighbors = four_neighbors,
    avg_resistances = avg_resistances,
    solver = solver,
    write_voltage = TRUE
  )

  # Run Circuitscape
  julia_expr <- paste0(
    'Circuitscape.compute("', gsub("\\\\", "/", ini_path), '")'
  )
  run_julia(julia_expr, verbose = verbose)

  # Parse and return output rasters
  parse_cs_output(work_dir, prefix, input_crs)
}
