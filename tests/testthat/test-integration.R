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

# INI key audit -------------------------------------------------------------
# circuitscaper writes every INI key itself, and the Julia packages silently
# ignore keys they don't recognize. These tests build configs exercising every
# optional key and check them against the installed upstream versions.

test_that("upstream supported-key lookups work", {
  skip_if_no_julia()
  expect_true(length(supported_ini_keys("Circuitscape")) > 0)
  expect_true(length(supported_ini_keys("Omniscape")) > 0)
})

test_that("all Circuitscape INI keys are recognized upstream", {
  skip_if_no_julia()
  supported <- supported_ini_keys("Circuitscape")
  skip_if(is.null(supported), "Circuitscape key lookup unavailable")

  tmp_dir <- tempfile("keys_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini_pairwise <- build_cs_config(
    mode = "pairwise", resistance_file = "/r.asc", output_dir = tmp_dir,
    output_prefix = "pw", locations_file = "/l.asc",
    short_circuit_file = "/sc.asc", included_pairs_file = "/pairs.txt",
    variable_source_file = "/vs.txt", four_neighbors = TRUE,
    avg_resistances = TRUE, write_voltage = TRUE
  )
  ini_advanced <- build_cs_config(
    mode = "advanced", resistance_file = "/r.asc", output_dir = tmp_dir,
    output_prefix = "adv", source_file = "/s.asc", ground_file = "/g.asc",
    use_unit_currents = TRUE, use_direct_grounds = TRUE
  )
  expect_equal(warn_unsupported_ini_keys(ini_pairwise, supported,
                                         "Circuitscape"), character())
  expect_equal(warn_unsupported_ini_keys(ini_advanced, supported,
                                         "Circuitscape"), character())
})

test_that("all Omniscape INI keys are recognized upstream", {
  skip_if_no_julia()
  supported <- supported_ini_keys("Omniscape")
  skip_if(is.null(supported), "Omniscape key lookup unavailable")

  tmp_dir <- tempfile("keys_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  ini <- build_os_config(
    resistance_file = "/r.asc", radius = 5, output_dir = tmp_dir,
    source_file = "/s.asc",
    conditions = list(
      list(present_file = "/c1.asc", future_file = "/c1f.asc",
           type = "within", lower = -1, upper = 1),
      list(present_file = "/c2.asc", future_file = "/c2f.asc",
           type = "equal")
    )
  )
  ini_from_res <- build_os_config(
    resistance_file = "/r.asc", radius = 5, output_dir = tmp_dir,
    r_cutoff = 10
  )
  expect_equal(warn_unsupported_ini_keys(ini, supported, "Omniscape"),
               character())
  expect_equal(warn_unsupported_ini_keys(ini_from_res, supported, "Omniscape"),
               character())
})

# Conditional connectivity behavior -----------------------------------------
# Uniform landscape with uniform sources, so that condition layers are the
# only thing that varies between runs.

cond_landscape <- function(nrow = 20, ncol = 30) {
  terra::rast(nrows = nrow, ncols = ncol, xmin = 0, xmax = ncol,
              ymin = 0, ymax = nrow, vals = 1)
}

run_cond <- function(condition = NULL, res = cond_landscape()) {
  out <- os_run(res, radius = 4, source_strength = res,
                condition = condition,
                calc_normalized_current = FALSE, calc_flow_potential = FALSE)
  terra::values(out$cumulative_current, mat = FALSE)
}

test_that("unbounded 'within' condition reproduces unconditional results", {
  skip_if_no_julia()
  res <- cond_landscape()
  set.seed(1)
  cond <- terra::init(res, fun = stats::runif)
  expect_equal(
    run_cond(os_condition(cond, lower = -Inf, upper = Inf), res),
    run_cond(NULL, res),
    tolerance = 1e-6
  )
})

test_that("'within' bounds that exclude all sources yield zero current", {
  skip_if_no_julia()
  res <- cond_landscape()
  cond <- res * 0  # source - target is always 0, outside [1, 2]
  current <- run_cond(os_condition(cond, lower = 1, upper = 2), res)
  expect_equal(max(abs(current), na.rm = TRUE), 0, tolerance = 1e-10)
})

test_that("'equal' condition is applied (not silently ignored)", {
  skip_if_no_julia()
  res <- cond_landscape()
  # Unique value per cell: no source matches any target
  unique_vals <- terra::init(res, "cell")
  current <- run_cond(os_condition(unique_vals, type = "equal"), res)
  expect_equal(max(abs(current), na.rm = TRUE), 0, tolerance = 1e-10)
})

test_that("future condition layer is compared at targets", {
  skip_if_no_julia()
  res <- cond_landscape()
  present <- res * 0 + 1
  future <- res * 0 + 2

  # Present-vs-present: every pair matches, same as unconditional
  expect_equal(run_cond(os_condition(present, type = "equal"), res),
               run_cond(NULL, res), tolerance = 1e-6)
  # Present source (1) vs future target (2): no pair matches
  current <- run_cond(os_condition(present, future = future, type = "equal"),
                      res)
  expect_equal(max(abs(current), na.rm = TRUE), 0, tolerance = 1e-10)
  # 'within' with future: source - target_future = -1, inside [-1.5, -0.5]
  expect_equal(
    run_cond(os_condition(present, future = future,
                          lower = -1.5, upper = -0.5), res),
    run_cond(NULL, res), tolerance = 1e-6
  )
})

test_that("two conditions are both enforced", {
  skip_if_no_julia()
  res <- cond_landscape()
  all_match <- os_condition(res * 0 + 1, type = "equal")
  none_match <- os_condition(terra::init(res, "cell"), type = "equal")
  unconditional <- run_cond(NULL, res)

  expect_equal(run_cond(list(all_match, all_match), res), unconditional,
               tolerance = 1e-6)
  current <- run_cond(list(all_match, none_match), res)
  expect_equal(max(abs(current), na.rm = TRUE), 0, tolerance = 1e-10)
})

test_that("'equal' zones reduce current across the zone boundary", {
  skip_if_no_julia()
  res <- cond_landscape(nrow = 20, ncol = 30)
  zones <- (terra::init(res, "col") > 15) + 1

  col_means <- function(v) colMeans(matrix(v, nrow = 20, byrow = TRUE))
  boundary_ratio <- function(v) {
    m <- col_means(v)
    mean(m[15:16]) / mean(m[c(7:8, 23:24)])
  }

  ratio_uncond <- boundary_ratio(run_cond(NULL, res))
  ratio_cond <- boundary_ratio(run_cond(zones, res))
  expect_lt(ratio_cond, 0.9 * ratio_uncond)
})
