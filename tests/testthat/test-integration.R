# Integration tests require Julia + Circuitscape + Omniscape
# These are skipped on CRAN and on systems without Julia

test_that("cs_pairwise runs end-to-end", {
  skip_if_no_julia()
  skip_if_not_installed("terra")

  res <- terra::rast(system.file("testdata/resistance.asc",
                                 package = "circuitscaper"))
  locs <- terra::rast(system.file("testdata/locations.asc",
                                  package = "circuitscaper"))

  result <- cs_pairwise(res, locs, verbose = FALSE)

  expect_type(result, "list")
  expect_s4_class(result$current_map, "SpatRaster")
  expect_true(!is.null(result$resistance_matrix))
  expect_true(is.matrix(result$resistance_matrix))
})

test_that("cs_pairwise accepts coordinate matrix", {
  skip_if_no_julia()
  skip_if_not_installed("terra")

  res <- terra::rast(system.file("testdata/resistance.asc",
                                 package = "circuitscaper"))

  # 3 focal nodes as coordinates (matching test data locations)
  coords <- matrix(c(1.5, 8.5,
                      8.5, 8.5,
                      4.5, 1.5), ncol = 2, byrow = TRUE)

  result <- cs_pairwise(res, coords, verbose = FALSE)

  expect_type(result, "list")
  expect_s4_class(result$current_map, "SpatRaster")
  expect_true(is.matrix(result$resistance_matrix))
  expect_equal(nrow(result$resistance_matrix), 3)
})

test_that("cs_one_to_all runs end-to-end", {
  skip_if_no_julia()
  skip_if_not_installed("terra")

  res <- terra::rast(system.file("testdata/resistance.asc",
                                 package = "circuitscaper"))
  locs <- terra::rast(system.file("testdata/locations.asc",
                                  package = "circuitscaper"))

  result <- cs_one_to_all(res, locs, verbose = FALSE)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::nlyr(result) >= 2)
})

test_that("cs_all_to_one runs end-to-end", {
  skip_if_no_julia()
  skip_if_not_installed("terra")

  res <- terra::rast(system.file("testdata/resistance.asc",
                                 package = "circuitscaper"))
  locs <- terra::rast(system.file("testdata/locations.asc",
                                  package = "circuitscaper"))

  result <- cs_all_to_one(res, locs, verbose = FALSE)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::nlyr(result) >= 2)
})

test_that("cs_advanced runs end-to-end", {
  skip_if_no_julia()
  skip_if_not_installed("terra")

  res <- terra::rast(system.file("testdata/resistance.asc",
                                 package = "circuitscaper"))

  # Create simple source and ground
  src <- res * 0
  src[1, 1] <- 1
  gnd <- res * 0
  gnd[10, 10] <- 10

  result <- cs_advanced(res, src, gnd, verbose = FALSE)

  expect_s4_class(result, "SpatRaster")
  expect_true("current" %in% names(result))
  expect_true("voltage" %in% names(result))
})

test_that("os_run runs end-to-end", {
  skip_if_no_julia()
  skip_if_not_installed("terra")

  res <- terra::rast(system.file("testdata/resistance.asc",
                                 package = "circuitscaper"))

  result <- os_run(res, radius = 3, block_size = 3L, verbose = FALSE)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::nlyr(result) >= 1)
})

test_that("CRS is preserved through round-trip", {
  skip_if_no_julia()
  skip_if_not_installed("terra")

  res <- terra::rast(system.file("testdata/resistance.asc",
                                 package = "circuitscaper"))
  locs <- terra::rast(system.file("testdata/locations.asc",
                                  package = "circuitscaper"))
  terra::crs(res) <- "EPSG:4326"
  terra::crs(locs) <- "EPSG:4326"

  result <- cs_pairwise(res, locs, verbose = FALSE)

  expect_equal(terra::crs(result$current_map), terra::crs(res))
})
