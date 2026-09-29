test_that("build_cs_config creates valid INI for pairwise mode", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    output_prefix = "test",
    locations_file = "/path/to/locations.asc",
    resistance_is = "resistances",
    four_neighbors = FALSE,
    solver = "cg+amg"
  )

  expect_true(file.exists(ini_path))
  content <- readLines(ini_path)

  # Check key sections and values
  expect_true(any(grepl("scenario = pairwise", content)))
  expect_true(any(grepl("habitat_file = /path/to/resistance.asc", content)))
  expect_true(any(grepl("point_file = /path/to/locations.asc", content)))
  expect_true(any(grepl("write_cur_maps = true", content)))
})

test_that("build_cs_config handles advanced mode", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "advanced",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    output_prefix = "test",
    source_file = "/path/to/source.asc",
    ground_file = "/path/to/ground.asc",
    write_voltage = TRUE
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("scenario = advanced", content)))
  expect_true(any(grepl("source_file = /path/to/source.asc", content)))
  expect_true(any(grepl("ground_file = /path/to/ground.asc", content)))
  expect_true(any(grepl("write_volt_maps = true", content)))
})

test_that("build_cs_config handles advanced mode options", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "advanced",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    source_file = "/path/to/source.asc",
    ground_file = "/path/to/ground.asc",
    ground_is = "conductances",
    use_unit_currents = TRUE,
    use_direct_grounds = TRUE,
    write_voltage = TRUE
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("ground_file_is_resistances = false", content)))
  expect_true(any(grepl("use_unit_currents = true", content)))
  expect_true(any(grepl("use_direct_grounds = true", content)))
})

test_that("build_cs_config advanced mode defaults match Circuitscape", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "advanced",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    source_file = "/path/to/source.asc",
    ground_file = "/path/to/ground.asc"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("ground_file_is_resistances = true", content)))
  expect_true(any(grepl("use_unit_currents = false", content)))
  expect_true(any(grepl("use_direct_grounds = false", content)))
})

test_that("build_cs_config handles conductances option", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/conductance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc",
    resistance_is = "conductances"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("habitat_map_is_resistances = false", content)))
})

test_that("build_cs_config handles short-circuit regions", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc",
    short_circuit_file = "/path/to/polygons.asc"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("use_polygons = true", content)))
  expect_true(any(grepl("polygon_file = /path/to/polygons.asc", content)))
})

test_that("build_cs_config handles write_voltage and cumulative_only", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc",
    write_voltage = TRUE,
    cumulative_only = FALSE
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("write_volt_maps = true", content)))
  expect_true(any(grepl("write_cum_cur_map_only = false", content)))
})

test_that("build_cs_config handles included pairs", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc",
    included_pairs_file = "/path/to/pairs.txt"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("use_included_pairs = true", content)))
  expect_true(any(grepl("included_pairs_file = /path/to/pairs.txt", content)))
})

test_that("build_cs_config handles source/ground conflict", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "advanced",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    source_file = "/path/to/source.asc",
    ground_file = "/path/to/ground.asc",
    source_ground_conflict = "rmvsrc"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("remove_src_or_gnd = rmvsrc", content)))
})

test_that("build_os_config creates valid INI", {
  tmp_dir <- tempfile("os_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_os_config(
    resistance_file = "/path/to/resistance.asc",
    radius = 100,
    output_dir = tmp_dir,
    block_size = 5L,
    source_threshold = 0.5,
    calc_normalized_current = TRUE,
    calc_flow_potential = TRUE
  )

  expect_true(file.exists(ini_path))
  content <- readLines(ini_path)

  expect_true(any(grepl("resistance_file = /path/to/resistance.asc", content)))
  expect_true(any(grepl("radius = 100", content)))
  expect_true(any(grepl("block_size = 5", content)))
  expect_true(any(grepl("source_threshold = 0.5", content)))
  expect_true(any(grepl("calc_normalized_current = true", content)))
  expect_true(any(grepl("source_from_resistance = true", content)))
})

test_that("build_os_config handles source file", {
  tmp_dir <- tempfile("os_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_os_config(
    resistance_file = "/path/to/resistance.asc",
    radius = 50,
    output_dir = tmp_dir,
    source_file = "/path/to/source.asc"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("source_file = /path/to/source.asc", content)))
  expect_true(any(grepl("source_from_resistance = false", content)))
})

test_that("build_cs_config handles variable source strengths", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "one-to-all",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc",
    variable_source_file = "/path/to/strengths.txt"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("use_variable_source_strengths = true", content)))
  expect_true(any(grepl("variable_source_file = /path/to/strengths.txt", content)))
})

test_that("build_cs_config omits variable source strengths when NULL", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("use_variable_source_strengths = false", content)))
  expect_false(any(grepl("variable_source_file", content)))
})

test_that("build_cs_config sets avg_resistances in connection scheme", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc",
    avg_resistances = TRUE
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("connect_using_avg_resistances = true", content)))
})

test_that("build_cs_config defaults avg_resistances to false", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("connect_using_avg_resistances = false", content)))
})

# Helper: build an Omniscape INI and return its lines
os_ini_lines <- function(conditions) {
  tmp_dir <- tempfile("os_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))
  ini_path <- build_os_config(
    resistance_file = "/path/to/resistance.asc",
    radius = 50,
    output_dir = tmp_dir,
    conditions = conditions
  )
  readLines(ini_path)
}

test_that("build_os_config writes no conditional section without conditions", {
  content <- os_ini_lines(NULL)
  expect_false(any(grepl("conditional", content)))
  expect_false(any(grepl("condition1", content)))
})

test_that("build_os_config writes an 'equal' condition", {
  content <- os_ini_lines(list(
    list(present_file = "/path/to/cond.asc", future_file = NULL,
         type = "equal")
  ))
  expect_true("conditional = true" %in% content)
  expect_true("n_conditions = 1" %in% content)
  expect_true("compare_to_future = none" %in% content)
  expect_true("condition1_file = /path/to/cond.asc" %in% content)
  expect_true("comparison1 = equal" %in% content)
  expect_false(any(grepl("condition1_lower|condition1_upper", content)))
  expect_false(any(grepl("future_file", content)))
  # Regression: the old, unrecognized key must not be written
  expect_false(any(grepl("condition1_type", content)))
})

test_that("build_os_config writes a bounded 'within' condition", {
  content <- os_ini_lines(list(
    list(present_file = "/path/to/cond.asc", future_file = NULL,
         type = "within", lower = -1.5, upper = 0.25)
  ))
  expect_true("comparison1 = within" %in% content)
  expect_true("condition1_lower = -1.5" %in% content)
  expect_true("condition1_upper = 0.25" %in% content)
})

test_that("build_os_config writes infinite bounds Julia can parse", {
  content <- os_ini_lines(list(
    list(present_file = "/path/to/cond.asc", future_file = NULL,
         type = "within", lower = -Inf, upper = 2)
  ))
  expect_true("condition1_lower = -Inf" %in% content)
  expect_true("condition1_upper = 2" %in% content)
})

test_that("build_os_config writes present-vs-future conditions", {
  content <- os_ini_lines(list(
    list(present_file = "/path/to/now.asc", future_file = "/path/to/fut.asc",
         type = "within", lower = -1, upper = 1)
  ))
  expect_true("compare_to_future = 1" %in% content)
  expect_true("condition1_future_file = /path/to/fut.asc" %in% content)
})

test_that("build_os_config sets compare_to_future for two conditions", {
  now1 <- list(present_file = "/c1.asc", future_file = NULL, type = "equal")
  fut1 <- list(present_file = "/c1.asc", future_file = "/c1f.asc",
               type = "equal")
  now2 <- list(present_file = "/c2.asc", future_file = NULL,
               type = "within", lower = 0, upper = 1)
  fut2 <- list(present_file = "/c2.asc", future_file = "/c2f.asc",
               type = "within", lower = 0, upper = 1)

  content <- os_ini_lines(list(now1, now2))
  expect_true("n_conditions = 2" %in% content)
  expect_true("compare_to_future = none" %in% content)
  expect_true("comparison1 = equal" %in% content)
  expect_true("comparison2 = within" %in% content)
  expect_true("condition2_file = /c2.asc" %in% content)

  expect_true("compare_to_future = 1" %in% os_ini_lines(list(fut1, now2)))
  expect_true("compare_to_future = 2" %in% os_ini_lines(list(now1, fut2)))
  both <- os_ini_lines(list(fut1, fut2))
  expect_true("compare_to_future = both" %in% both)
  expect_true("condition2_future_file = /c2f.asc" %in% both)
})

test_that("build_os_config rejects more than two conditions", {
  cond <- list(present_file = "/c.asc", future_file = NULL, type = "equal")
  expect_error(os_ini_lines(list(cond, cond, cond)), "one or two")
})

test_that("build_cs_config writes the four-neighbor key Circuitscape reads", {
  tmp_dir <- tempfile("cs_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_cs_config(
    mode = "pairwise",
    resistance_file = "/path/to/resistance.asc",
    output_dir = tmp_dir,
    locations_file = "/path/to/locations.asc",
    four_neighbors = TRUE
  )
  content <- readLines(ini_path)
  expect_true("connect_four_neighbors_only = true" %in% content)
  expect_false(any(grepl("^connect_four_neighbors =", content)))
})
