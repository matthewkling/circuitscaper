#' Build Circuitscape INI Configuration
#'
#' Constructs a Circuitscape INI configuration file from R arguments.
#'
#' @param mode Character. One of "pairwise", "one-to-all", "all-to-one",
#'   "advanced".
#' @param resistance_file Character. Path to resistance raster.
#' @param output_dir Character. Directory for output files.
#' @param output_prefix Character. Prefix for output filenames.
#' @param locations_file Character. Path to focal node raster (modes 1-3).
#' @param source_file Character. Path to source raster (advanced mode).
#' @param ground_file Character. Path to ground raster (advanced mode).
#' @param resistance_is Character. "resistances" or "conductances".
#' @param four_neighbors Logical. Use 4-neighbor connectivity.
#' @param solver Character. Solver type.
#' @param write_voltage Logical. Write voltage maps (advanced mode).
#'
#' @return Path to the written INI file.
#' @noRd
build_cs_config <- function(mode,
                            resistance_file,
                            output_dir,
                            output_prefix = "circuitscape",
                            locations_file = NULL,
                            source_file = NULL,
                            ground_file = NULL,
                            resistance_is = "resistances",
                            four_neighbors = FALSE,
                            solver = "cg+amg",
                            write_voltage = FALSE) {

  # Map R mode names to Circuitscape scenario names
  scenario_map <- c(
    "pairwise" = "pairwise",
    "one-to-all" = "one-to-all",
    "all-to-one" = "all-to-one",
    "advanced" = "advanced"
  )

  config <- list()

  # Habitat/resistance section
  config[["Habitat raster is resistances or conductances"]] <- list(
    habitat_map_is_resistances = if (resistance_is == "resistances") "true" else "false"
  )

  # Circuitscape mode section
  config[["Circuitscape mode"]] <- list(
    scenario = scenario_map[[mode]]
  )

  # Connection scheme
  connect_val <- if (four_neighbors) "connect_four_neighbors" else "connect_eight_neighbors"
  config[["Connection scheme for raster habitat data"]] <- list(
    connect_four_neighbors = if (four_neighbors) "true" else "false",
    connect_using_avg_resistances = "false"
  )

  # Short-circuit regions (default off)
  config[["Short circuit regions (aka polygons)"]] <- list(
    use_polygons = "false"
  )

  # Options
  config[["Options for advanced mode"]] <- list(
    ground_file_is_resistances = "true",
    source_file = if (!is.null(source_file)) source_file else "",
    ground_file = if (!is.null(ground_file)) ground_file else "",
    use_unit_currents = "false",
    use_direct_grounds = "false"
  )

  config[["Calculation options"]] <- list(
    solver = solver
  )

  config[["Options for pairwise and one-to-all and all-to-one modes"]] <- list(
    point_file = if (!is.null(locations_file)) locations_file else "",
    use_included_pairs = "false"
  )

  # Output options
  config[["Output options"]] <- list(
    write_cur_maps = "true",
    write_volt_maps = if (write_voltage) "true" else "false",
    output_file = file.path(output_dir, output_prefix),
    write_cum_cur_map_only = "true",
    log_transform_maps = "false",
    write_max_cur_maps = "false"
  )

  # Input raster
  config[["Habitat raster"]] <- list(
    habitat_file = resistance_file
  )

  # Write INI file
  ini_path <- file.path(output_dir, paste0(output_prefix, ".ini"))
  write_ini(config, ini_path)
  ini_path
}


#' Build Omniscape INI Configuration
#'
#' Constructs an Omniscape INI configuration file from R arguments.
#'
#' @param resistance_file Character. Path to resistance raster.
#' @param radius Numeric. Moving window radius in pixels.
#' @param output_dir Character. Directory for output files.
#' @param source_file Character or NULL. Path to source strength raster.
#' @param block_size Integer. Aggregation block size.
#' @param source_threshold Numeric. Minimum source strength.
#' @param resistance_is Character. "resistances" or "conductances".
#' @param calc_normalized_current Logical.
#' @param calc_flow_potential Logical.
#' @param condition_file Character or NULL. Path to condition raster.
#' @param condition_type Character or NULL.
#' @param parallelize Logical.
#' @param julia_threads Integer.
#' @param solver Character.
#'
#' @return Path to the written INI file.
#' @noRd
build_os_config <- function(resistance_file,
                            radius,
                            output_dir,
                            source_file = NULL,
                            block_size = 1L,
                            source_threshold = 0,
                            resistance_is = "resistances",
                            calc_normalized_current = TRUE,
                            calc_flow_potential = TRUE,
                            condition_file = NULL,
                            condition_type = NULL,
                            parallelize = FALSE,
                            julia_threads = 2L,
                            solver = "cg+amg") {

  config <- list()

  # Required inputs — use a subdirectory for output so Omniscape doesn't

  # append _1 to the path when it finds the directory already exists
  os_output_dir <- file.path(output_dir, "omniscape_output")
  config[["Required"]] <- list(
    resistance_file = resistance_file,
    radius = as.integer(radius),
    project_name = os_output_dir
  )

  # General options
  config[["General options"]] <- list(
    block_size = as.integer(block_size),
    source_threshold = source_threshold,
    resistance_is_conductance = if (resistance_is == "conductances") "true" else "false",
    calc_normalized_current = if (calc_normalized_current) "true" else "false",
    calc_flow_potential = if (calc_flow_potential) "true" else "false",
    solver = solver,
    parallelize = if (parallelize) "true" else "false",
    parallel_batch_size = 10L
  )

  # Source strength
  if (!is.null(source_file)) {
    config[["General options"]]$source_file <- source_file
    config[["General options"]]$source_from_resistance <- "false"
  } else {
    config[["General options"]]$source_from_resistance <- "true"
  }

  # Conditional connectivity
  if (!is.null(condition_file)) {
    config[["Conditional connectivity"]] <- list(
      conditional = "true",
      condition1_file = condition_file
    )
    if (!is.null(condition_type)) {
      config[["Conditional connectivity"]]$condition1_type <- condition_type
    }
  }

  # Write INI file
  ini_path <- file.path(output_dir, "omniscape.ini")
  write_ini(config, ini_path)
  ini_path
}
