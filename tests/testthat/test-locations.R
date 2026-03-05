test_that("cs_locations creates raster from matrix", {
  skip_if_not_installed("terra")
  res <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                     ymin = 0, ymax = 10, vals = 1)

  coords <- matrix(c(1.5, 8.5,
                      8.5, 8.5,
                      4.5, 1.5), ncol = 2, byrow = TRUE)
  locs <- cs_locations(coords, res)

  expect_s4_class(locs, "SpatRaster")
  expect_equal(as.vector(terra::ext(locs)), as.vector(terra::ext(res)))
  expect_equal(terra::res(locs), terra::res(res))

  # Check IDs are assigned correctly
  vals <- terra::values(locs)
  expect_true(1 %in% vals)
  expect_true(2 %in% vals)
  expect_true(3 %in% vals)
  # Background is 0
  expect_equal(sum(vals > 0), 3)
})

test_that("cs_locations creates raster from data.frame", {
  skip_if_not_installed("terra")
  res <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                     ymin = 0, ymax = 10, vals = 1)

  coords <- data.frame(x = c(1.5, 8.5, 4.5),
                        y = c(8.5, 8.5, 1.5))
  locs <- cs_locations(coords, res)

  expect_s4_class(locs, "SpatRaster")
  vals <- terra::values(locs)
  expect_equal(sum(vals > 0), 3)
})

test_that("cs_locations errors on points outside extent", {
  skip_if_not_installed("terra")
  res <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                     ymin = 0, ymax = 10, vals = 1)

  coords <- matrix(c(5, 5, 15, 5), ncol = 2, byrow = TRUE)
  expect_error(cs_locations(coords, res), "outside raster extent")
})

test_that("cs_locations errors on duplicate cells", {
  skip_if_not_installed("terra")
  res <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                     ymin = 0, ymax = 10, vals = 1)

  # Two points in the same cell
  coords <- matrix(c(0.3, 5, 0.7, 5), ncol = 2, byrow = TRUE)
  expect_error(cs_locations(coords, res), "same raster cell")
})

test_that("cs_locations errors on fewer than 2 nodes", {
  skip_if_not_installed("terra")
  res <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                     ymin = 0, ymax = 10, vals = 1)

  coords <- matrix(c(5, 5), ncol = 2)
  expect_error(cs_locations(coords, res), "At least 2")
})

test_that("cs_locations errors on non-raster resistance", {
  coords <- matrix(c(1, 2, 3, 4), ncol = 2)
  expect_error(cs_locations(coords, 42), "must be a SpatRaster")
})

test_that("cs_locations preserves CRS from template", {
  skip_if_not_installed("terra")
  res <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                     ymin = 0, ymax = 10, vals = 1)
  terra::crs(res) <- "EPSG:4326"

  coords <- matrix(c(1.5, 8.5, 8.5, 1.5), ncol = 2, byrow = TRUE)
  locs <- cs_locations(coords, res)

  expect_equal(terra::crs(locs), terra::crs(res))
})

test_that("cs_locations assigns IDs sequentially by row order", {
  skip_if_not_installed("terra")
  res <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10,
                     ymin = 0, ymax = 10, vals = 1)

  # Three points at known locations
  coords <- matrix(c(0.5, 9.5,   # top-left cell
                      9.5, 9.5,   # top-right cell
                      0.5, 0.5),  # bottom-left cell
                   ncol = 2, byrow = TRUE)
  locs <- cs_locations(coords, res)

  # Extract values at those coordinates
  cell1 <- terra::cellFromXY(res, coords[1, , drop = FALSE])
  cell2 <- terra::cellFromXY(res, coords[2, , drop = FALSE])
  cell3 <- terra::cellFromXY(res, coords[3, , drop = FALSE])

  expect_equal(locs[cell1][[1]], 1)
  expect_equal(locs[cell2][[1]], 2)
  expect_equal(locs[cell3][[1]], 3)
})
