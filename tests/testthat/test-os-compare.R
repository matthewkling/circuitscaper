test_that("os_compare computes difference and ratio", {
  skip_if_not_installed("terra")

  baseline <- terra::rast(nrows = 5, ncols = 5, vals = rep(2, 25))
  future <- terra::rast(nrows = 5, ncols = 5, vals = rep(4, 25))
  names(baseline) <- "normalized_current"
  names(future) <- "normalized_current"

  result <- os_compare(baseline, future)

  expect_s4_class(result, "SpatRaster")
  expect_equal(terra::nlyr(result), 2L)
  expect_equal(names(result), c("difference", "ratio"))

  # difference = 4 - 2 = 2
  expect_equal(unique(terra::values(result[["difference"]]))[1], 2)
  # ratio = 4 / 2 = 2
  expect_equal(unique(terra::values(result[["ratio"]]))[1], 2)
})

test_that("os_compare errors on missing metric layer", {
  skip_if_not_installed("terra")

  baseline <- terra::rast(nrows = 5, ncols = 5, vals = 1)
  future <- terra::rast(nrows = 5, ncols = 5, vals = 2)
  names(baseline) <- "cumulative_current"
  names(future) <- "cumulative_current"

  expect_error(
    os_compare(baseline, future, metric = "normalized_current"),
    "not found in baseline"
  )
})

test_that("os_compare errors on non-SpatRaster input", {
  expect_error(
    os_compare(1, 2),
    "must be a SpatRaster"
  )
})

test_that("os_compare errors on mismatched extents", {
  skip_if_not_installed("terra")

  baseline <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 5,
                          ymin = 0, ymax = 5, vals = 1)
  future <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 10,
                        ymin = 0, ymax = 5, vals = 2)
  names(baseline) <- "normalized_current"
  names(future) <- "normalized_current"

  expect_error(
    os_compare(baseline, future),
    "different extents"
  )
})
