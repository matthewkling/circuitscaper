# Julia version checks. These use fake Julia binaries (shell scripts that
# print a version), so they run without Julia.

# Create a fake Julia whose `--version` prints `version_line`. Returns its
# bin/ directory.
fake_julia_version <- function(version_line) {
  bin_dir <- file.path(tempfile("julia_"), "bin")
  dir.create(bin_dir, recursive = TRUE)
  exe <- file.path(bin_dir, "julia")
  writeLines(c("#!/bin/sh", paste0("echo '", version_line, "'")), exe)
  Sys.chmod(exe, "755")
  bin_dir
}

test_that("parse_julia_version handles release and dev versions", {
  expect_equal(parse_julia_version("julia version 1.12.1"),
               package_version("1.12.1"))
  expect_equal(parse_julia_version("julia version 1.13.0-DEV"),
               package_version("1.13.0"))
  expect_null(parse_julia_version("not julia"))
  expect_null(parse_julia_version(character(0)))
})

test_that("version comparison is numeric, not alphabetical", {
  # The bug in CRAN JuliaCall: "1.9.4" > "1.12.1" as strings
  expect_true("1.9.4" > "1.12.1")
  expect_true(parse_julia_version("julia version 1.12.1") >= min_julia_version())
  expect_true(parse_julia_version("julia version 1.9.4") < min_julia_version())
})

test_that("check_julia_version stops on Julia 1.9 with the fix", {
  skip_on_os("windows")
  bin <- file.path(fake_julia_version("julia version 1.9.4"), "julia")
  expect_error(check_julia_version(bin), "Julia 1.9.4 .* is too old")
  expect_error(check_julia_version(bin), "cs_install_julia(force = TRUE)",
               fixed = TRUE)
  expect_error(check_julia_version(bin), "JuliaInterop/JuliaCall",
               fixed = TRUE)
})

test_that("check_julia_version accepts supported and unknown versions", {
  skip_on_os("windows")
  ok <- file.path(fake_julia_version("julia version 1.12.1"), "julia")
  expect_silent(check_julia_version(ok))
  odd <- file.path(fake_julia_version("something unexpected"), "julia")
  expect_silent(check_julia_version(odd))
  expect_silent(check_julia_version(NULL))
  expect_silent(check_julia_version(file.path(tempfile(), "julia")))
})

test_that("cs_setup stops on an old Julia before starting it", {
  skip_on_os("windows")
  skip_if(.cs_env$julia_ready, "Julia is already running in this session")
  old <- fake_julia_version("julia version 1.9.4")
  expect_error(suppressMessages(cs_setup(julia_home = old)), "too old")
  expect_false(.cs_env$julia_ready)
})

test_that("cs_install_julia rejects an existing old Julia without force", {
  skip_on_os("windows")
  old_opt <- options(JULIA_HOME = NULL)
  on.exit(options(old_opt), add = TRUE)
  old_env <- Sys.getenv("JULIA_HOME", unset = NA)
  on.exit(if (is.na(old_env)) Sys.unsetenv("JULIA_HOME") else
    Sys.setenv(JULIA_HOME = old_env), add = TRUE)
  Sys.setenv(JULIA_HOME = fake_julia_version("julia version 1.9.4"))

  expect_error(cs_install_julia(), "cs_install_julia(force = TRUE)",
               fixed = TRUE)
})

test_that("cs_install_julia rejects unsupported version requests", {
  expect_error(cs_install_julia(force = TRUE, version = "1.9.4"),
               "requires Julia >= 1.10")
  expect_error(cs_install_julia(force = TRUE, version = "newest"),
               "must be \"latest\"")
})

test_that("outdated JuliaCall is detected from julia_latest_version()", {
  # Bodies of julia_latest_version() before and after JuliaCall's fix
  cran <- function() {
    versions <- list()
    max(names(Filter(function(v) v$stable, versions)))
  }
  fixed <- function() {
    versions <- list()
    max(numeric_version(names(Filter(function(v) v$stable, versions))))
  }
  expect_true(juliacall_install_is_outdated(cran))
  expect_false(juliacall_install_is_outdated(fixed))
  expect_true(juliacall_install_is_outdated(fun = "not a function"))
  expect_type(juliacall_install_is_outdated(), "logical")
})

test_that("outdated JuliaCall message gives both ways forward", {
  msg <- juliacall_outdated_message()
  expect_match(msg, "remotes::install_github(\"JuliaInterop/JuliaCall\")",
               fixed = TRUE)
  expect_match(msg, "julialang.org/install", fixed = TRUE)
})
