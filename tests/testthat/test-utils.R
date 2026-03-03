test_that("write_ini creates valid INI file", {
  tmp <- tempfile(fileext = ".ini")
  on.exit(unlink(tmp))

  config <- list(
    "Section One" = list(
      key1 = "value1",
      key2 = 42,
      key3 = TRUE
    ),
    "Section Two" = list(
      path = "/some/path/file.asc",
      flag = FALSE
    )
  )

  write_ini(config, tmp)

  lines <- readLines(tmp)
  expect_true("[Section One]" %in% lines)
  expect_true("key1 = value1" %in% lines)
  expect_true("key2 = 42" %in% lines)
  expect_true("key3 = true" %in% lines)
  expect_true("[Section Two]" %in% lines)
  expect_true("path = /some/path/file.asc" %in% lines)
  expect_true("flag = false" %in% lines)
})

test_that("validate_raster_match catches mismatched extents", {
  skip_if_not_installed("terra")

  r1 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                    ymin = 0, ymax = 10, vals = 1)
  r2 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 20,
                    ymin = 0, ymax = 10, vals = 1)

  expect_error(
    validate_raster_match(r1, r2, "r1", "r2"),
    "different extents"
  )
})

test_that("validate_raster_match catches mismatched resolutions", {
  skip_if_not_installed("terra")

  r1 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                    ymin = 0, ymax = 10, vals = 1)
  r2 <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 10,
                    ymin = 0, ymax = 10, vals = 1)

  expect_error(
    validate_raster_match(r1, r2, "r1", "r2"),
    "different resolutions"
  )
})

test_that("validate_raster_match passes for matching rasters", {
  skip_if_not_installed("terra")

  r1 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                    ymin = 0, ymax = 10, vals = 1)
  r2 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                    ymin = 0, ymax = 10, vals = 2)

  expect_invisible(validate_raster_match(r1, r2, "r1", "r2"))
})


test_that("write_ini normalizes Windows backslashes", {
  tmp <- tempfile(fileext = ".ini")
  on.exit(unlink(tmp))

  config <- list(
    "Habitat raster" = list(
      habitat_file = "C:\\Users\\test\\data\\resistance.asc"
    )
  )

  write_ini(config, tmp)
  lines <- readLines(tmp)
  expect_true("habitat_file = C:/Users/test/data/resistance.asc" %in% lines)
})


test_that("validate_resistance_values warns on zeros", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 5, ncols = 5, vals = c(0, rep(1, 24)))
  expect_warning(validate_resistance_values(r, "resistances"), "zero values")
})

test_that("validate_resistance_values warns on negative values", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 5, ncols = 5, vals = c(-1, rep(1, 24)))
  expect_warning(validate_resistance_values(r, "resistances"), "negative values")
})

test_that("validate_resistance_values silent on valid raster", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 5, ncols = 5, vals = rep(1, 25))
  expect_silent(validate_resistance_values(r, "resistances"))
})

test_that("validate_resistance_values no-ops on file path", {
  expect_silent(validate_resistance_values("some/path.tif", "resistances"))
})

test_that("validate_resistance_values no zero warning for conductances", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 5, ncols = 5, vals = c(0, rep(1, 24)))
  # Zeros in conductance surfaces are fine (they mean no connectivity)
  expect_silent(validate_resistance_values(r, "conductances"))
})
