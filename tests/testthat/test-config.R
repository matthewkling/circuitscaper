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

test_that("build_os_config handles conditional connectivity", {
  tmp_dir <- tempfile("os_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_path <- build_os_config(
    resistance_file = "/path/to/resistance.asc",
    radius = 50,
    output_dir = tmp_dir,
    condition_file = "/path/to/condition.asc",
    condition_type = "within"
  )

  content <- readLines(ini_path)
  expect_true(any(grepl("conditional = true", content)))
  expect_true(any(grepl("condition1_file = /path/to/condition.asc", content)))
  expect_true(any(grepl("condition1_type = within", content)))
})
