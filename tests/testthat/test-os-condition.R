make_rast <- function(vals, nrow = 4, ncol = 4) {
  terra::rast(nrows = nrow, ncols = ncol, xmin = 0, xmax = ncol,
              ymin = 0, ymax = nrow, vals = vals)
}

# os_condition() -----------------------------------------------------------

test_that("os_condition infers type from presence of bounds", {
  r <- make_rast(1:16)
  expect_equal(os_condition(r)$type, "equal")
  expect_equal(os_condition(r, lower = -1, upper = 1)$type, "within")
})

test_that("os_condition stores bounds only for 'within'", {
  r <- make_rast(1:16)
  x <- os_condition(r, type = "within", lower = -2, upper = 3)
  expect_s3_class(x, "os_condition")
  expect_equal(x$lower, -2)
  expect_equal(x$upper, 3)
  expect_null(os_condition(r, type = "equal")$lower)
})

test_that("os_condition validates bounds", {
  r <- make_rast(1:16)
  expect_error(os_condition(r, type = "within"), "both required")
  expect_error(os_condition(r, type = "within", lower = 0), "both required")
  expect_error(os_condition(r, lower = 2, upper = 1), "less than or equal")
  expect_error(os_condition(r, lower = NA_real_, upper = 1), "non-missing")
  expect_error(os_condition(r, lower = c(0, 1), upper = 1), "single")
  expect_error(os_condition(r, lower = "a", upper = 1), "number")
  expect_error(os_condition(r, type = "equal", lower = 0, upper = 1),
               "only apply")
})

test_that("os_condition accepts infinite bounds", {
  r <- make_rast(1:16)
  x <- os_condition(r, lower = -Inf, upper = 0)
  expect_equal(x$lower, -Inf)
  expect_silent(os_condition(r, lower = -Inf, upper = Inf))
})

test_that("os_condition validates layers", {
  r <- make_rast(1:16)
  expect_error(os_condition(c(r, r)), "single-layer")
  expect_error(os_condition(42), "SpatRaster or a file path")
  expect_error(os_condition("/no/such/file.asc"), "File not found")
  expect_error(os_condition(r, future = make_rast(1:25, 5, 5)),
               "different extents")
})

test_that("os_condition accepts file paths", {
  r <- make_rast(1:16)
  path <- tempfile(fileext = ".tif")
  terra::writeRaster(r, path)
  on.exit(unlink(path))
  x <- os_condition(path, future = path, lower = 0, upper = 1)
  expect_equal(x$present, path)
  expect_equal(x$future, path)
})

test_that("os_condition warns on non-integer values with 'equal'", {
  expect_warning(os_condition(make_rast(seq(0.5, 8, by = 0.5)), type = "equal"),
                 "non-integer")
  expect_warning(
    os_condition(make_rast(1:16), future = make_rast(1:16 + 0.1),
                 type = "equal"),
    "`future` layer"
  )
  expect_silent(os_condition(make_rast(c(1:15, NA)), type = "equal"))
})

test_that("print.os_condition describes the rule", {
  r <- make_rast(1:16)
  expect_output(print(os_condition(r)), "equal")
  out <- capture.output(print(os_condition(r, future = r, lower = -1, upper = 2)))
  expect_true(any(grepl("target \\+ -1 <= source <= target \\+ 2", out)))
  expect_true(any(grepl("future", out)))
})

# resolve_conditions() -----------------------------------------------------

test_that("resolve_conditions handles NULL", {
  expect_null(resolve_conditions(NULL))
})

test_that("a bare raster is shorthand for an 'equal' condition", {
  r <- make_rast(1:16)
  out <- resolve_conditions(r)
  expect_length(out, 1)
  expect_s3_class(out[[1]], "os_condition")
  expect_equal(out[[1]]$type, "equal")
})

test_that("resolve_conditions accepts one or two conditions", {
  r <- make_rast(1:16)
  a <- os_condition(r)
  b <- os_condition(r, lower = 0, upper = 1)
  expect_length(resolve_conditions(a), 1)
  out <- resolve_conditions(list(a, b))
  expect_length(out, 2)
  expect_equal(out[[2]]$type, "within")
  # bare rasters inside a list are coerced too
  expect_equal(resolve_conditions(list(r, b))[[1]]$type, "equal")
})

test_that("resolve_conditions rejects bad input", {
  r <- make_rast(1:16)
  a <- os_condition(r)
  expect_error(resolve_conditions(list(a, a, a)), "at most two")
  expect_error(resolve_conditions(list()), "at most two")
  expect_error(resolve_conditions(list(a, 5)), "Each element")
  expect_error(resolve_conditions(5), "must be an os_condition")
})

test_that("deprecated condition_type still works for 'equal'", {
  r <- make_rast(1:16)
  expect_warning(out <- resolve_conditions(r, "equal"), "deprecated")
  expect_equal(out[[1]]$type, "equal")
})

test_that("deprecated condition_type = 'within' errors helpfully", {
  r <- make_rast(1:16)
  expect_error(
    suppressWarnings(resolve_conditions(r, "within")),
    "requires bounds"
  )
  expect_error(
    suppressWarnings(resolve_conditions(os_condition(r), "equal")),
    "cannot be combined"
  )
})

# check_conditions_against_inputs() ----------------------------------------

test_that("condition layers must align with resistance", {
  res <- make_rast(1)
  cond <- list(os_condition(make_rast(1:25, 5, 5)))
  expect_error(check_conditions_against_inputs(cond, res), "different extents")
})

test_that("NA condition values at source cells trigger a warning", {
  res <- make_rast(1)
  cond <- list(os_condition(make_rast(c(NA, NA, 3:16))))
  expect_warning(check_conditions_against_inputs(cond, res),
                 "Condition 1 \\(present layer\\) is NA at 2 source cell")

  fut <- list(os_condition(make_rast(1:16), future = make_rast(c(NA, 2:16)),
                           lower = 0, upper = 1))
  expect_warning(check_conditions_against_inputs(fut, res),
                 "future layer\\) is NA at 1 source cell")
})

test_that("NA condition values outside source cells are fine", {
  res <- make_rast(c(NA, NA, rep(1, 14)))
  cond <- list(os_condition(make_rast(c(NA, NA, 3:16))))
  expect_silent(check_conditions_against_inputs(cond, res))

  # Sources defined by source_strength and threshold
  res <- make_rast(1)
  src <- make_rast(c(0, 0, rep(1, 14)))
  expect_silent(check_conditions_against_inputs(cond, res,
                                                source_strength = src))
  expect_warning(check_conditions_against_inputs(
    cond, res, source_strength = src, source_threshold = -1
  ), "NA at 2")

  # Sources excluded by r_cutoff
  res <- make_rast(c(100, 100, rep(1, 14)))
  expect_silent(check_conditions_against_inputs(cond, res, r_cutoff = 50))
})

test_that("coverage check is skipped for file-path inputs", {
  path <- tempfile(fileext = ".tif")
  terra::writeRaster(make_rast(c(NA, 2:16)), path)
  on.exit(unlink(path))
  cond <- list(os_condition(path))
  expect_silent(check_conditions_against_inputs(cond, make_rast(1)))
})

# INI key checking ---------------------------------------------------------

test_that("read_ini_keys extracts keys and skips sections and comments", {
  path <- tempfile(fileext = ".ini")
  on.exit(unlink(path))
  writeLines(c("[Section one]", "a = 1", "  b_c = /x/y = z", "",
               "# comment = no", "; also = no", "[Two]", "d=true"), path)
  expect_equal(read_ini_keys(path), c("a", "b_c", "d"))
})

test_that("warn_unsupported_ini_keys flags unknown keys", {
  path <- tempfile(fileext = ".ini")
  on.exit(unlink(path))
  writeLines(c("[S]", "good = 1", "bad = 2"), path)

  expect_warning(bad <- warn_unsupported_ini_keys(path, c("good"), "Omniscape"),
                 "Omniscape.jl does not recognize.*bad")
  expect_equal(bad, "bad")
  expect_silent(warn_unsupported_ini_keys(path, c("good", "bad"), "Omniscape"))
  expect_silent(warn_unsupported_ini_keys(path, NULL, "Omniscape"))
})
