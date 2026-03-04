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
#' @param ground_is Character. "resistances" or "conductances" (advanced mode).
#' @param use_unit_currents Logical. Set all sources to 1 amp (advanced mode).
#' @param use_direct_grounds Logical. Tie grounds directly to ground (advanced mode).
#' @param short_circuit_file Character or NULL. Path to short-circuit region raster.
#' @param included_pairs_file Character or NULL. Path to included pairs file.
#' @param source_ground_conflict Character. How to handle source/ground overlap (advanced mode).
#' @param four_neighbors Logical. Use 4-neighbor connectivity.
#' @param avg_resistances Logical. Use average resistance for diagonal connections.
#' @param solver Character. Solver type.
#' @param write_voltage Logical. Write voltage maps (advanced mode).
#' @param variable_source_file Character or NULL. Path to variable source
#'   strengths file (tab-delimited, node ID and strength columns).
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
                            ground_is = "resistances",
                            use_unit_currents = FALSE,
                            use_direct_grounds = FALSE,
                            short_circuit_file = NULL,
                            included_pairs_file = NULL,
                            source_ground_conflict = "keepall",
                            four_neighbors = FALSE,
                            avg_resistances = FALSE,
                            solver = "cg+amg",
                            write_voltage = FALSE,
                            cumulative_only = TRUE,
                            variable_source_file = NULL) {

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
  config[["Connection scheme for raster habitat data"]] <- list(
    connect_four_neighbors = if (four_neighbors) "true" else "false",
    connect_using_avg_resistances = if (avg_resistances) "true" else "false"
  )

  # Short-circuit regions
  if (!is.null(short_circuit_file)) {
    config[["Short circuit regions (aka polygons)"]] <- list(
      use_polygons = "true",
      polygon_file = short_circuit_file
    )
  } else {
    config[["Short circuit regions (aka polygons)"]] <- list(
      use_polygons = "false"
    )
  }

  # Options
  config[["Options for advanced mode"]] <- list(
    ground_file_is_resistances = if (ground_is == "resistances") "true" else "false",
    source_file = if (!is.null(source_file)) source_file else "",
    ground_file = if (!is.null(ground_file)) ground_file else "",
    use_unit_currents = if (use_unit_currents) "true" else "false",
    use_direct_grounds = if (use_direct_grounds) "true" else "false",
    remove_src_or_gnd = source_ground_conflict
  )

  config[["Calculation options"]] <- list(
    solver = solver
  )

  pairs_opts <- list(
    point_file = if (!is.null(locations_file)) locations_file else "",
    use_included_pairs = if (!is.null(included_pairs_file)) "true" else "false",
    use_variable_source_strengths = if (!is.null(variable_source_file)) "true" else "false"
  )
  if (!is.null(included_pairs_file)) {
    pairs_opts$included_pairs_file <- included_pairs_file
  }
  if (!is.null(variable_source_file)) {
    pairs_opts$variable_source_file <- variable_source_file
  }
  config[["Options for pairwise and one-to-all and all-to-one modes"]] <- pairs_opts

  # Output options
  config[["Output options"]] <- list(
    write_cur_maps = "true",
    write_volt_maps = if (write_voltage) "true" else "false",
    output_file = file.path(output_dir, output_prefix),
    write_cum_cur_map_only = if (cumulative_only) "true" else "false",
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
                            r_cutoff = Inf,
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
    if (is.finite(r_cutoff)) {
      config[["General options"]]$r_cutoff <- r_cutoff
    }
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
