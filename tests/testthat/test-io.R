test_that("ensure_asc returns path for existing file", {
  tmp <- tempfile(fileext = ".asc")
  writeLines("test", tmp)
  on.exit(unlink(tmp))

  result <- ensure_asc(tmp, tempdir(), "test")
  expect_equal(result, normalizePath(tmp))
})

test_that("ensure_asc errors for non-existent file", {
  expect_error(
    ensure_asc("/nonexistent/path.asc", tempdir(), "test"),
    "File not found"
  )
})

test_that("ensure_asc writes SpatRaster to ASC", {
  skip_if_not_installed("terra")

  tmp_dir <- tempfile("io_test_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  r <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 5,
                   ymin = 0, ymax = 5, vals = 1:25)

  result <- ensure_asc(r, tmp_dir, "testraster")
  expect_true(file.exists(result))
  expect_true(grepl("testraster\\.asc$", result))

  # Read back and check
  r2 <- terra::rast(result)
  expect_equal(terra::nrow(r2), 5L)
  expect_equal(terra::ncol(r2), 5L)
})

test_that("ensure_asc errors for invalid input", {
  expect_error(
    ensure_asc(42, tempdir(), "test"),
    "must be a SpatRaster"
  )
})

test_that("get_input_crs extracts CRS from SpatRaster", {
  skip_if_not_installed("terra")

  r <- terra::rast(nrows = 5, ncols = 5, vals = 1:25)
  terra::crs(r) <- "EPSG:4326"

  crs_val <- get_input_crs(r)
  expect_true(nchar(crs_val) > 0)
})

test_that("get_input_crs returns empty string for no CRS", {
  skip_if_not_installed("terra")

  r <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 5,
                   ymin = 0, ymax = 5, vals = 1:25, crs = "")

  crs_val <- get_input_crs(r)
  expect_equal(crs_val, "")
})
