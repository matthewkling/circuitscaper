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
  # Guards that must stop before Julia starts or anything downloads; if one
  # regressed, this test would start or install Julia, so never on CRAN.
  skip_on_cran()
  skip_on_os("windows")
  skip_if(.cs_env$julia_ready, "Julia is already running in this session")
  old <- fake_julia_version("julia version 1.9.4")
  expect_error(suppressMessages(cs_setup(julia_home = old)), "too old")
  expect_false(.cs_env$julia_ready)
})

test_that("cs_install_julia rejects an existing old Julia without force", {
  # Guards that must stop before Julia starts or anything downloads; if one
  # regressed, this test would start or install Julia, so never on CRAN.
  skip_on_cran()
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
  # Guards that must stop before Julia starts or anything downloads; if one
  # regressed, this test would start or install Julia, so never on CRAN.
  skip_on_cran()
  expect_error(cs_install_julia(force = TRUE, version = "1.9.4"),
               "requires Julia >= 1.10")
  expect_error(cs_install_julia(force = TRUE, version = "newest"),
               "must be \"latest\"")
  expect_error(cs_install_julia(force = TRUE, version = "lts"),
               "must be \"latest\"")
})

test_that("JuliaCall's opaque setup failure is recognized and explained", {
  raw <- paste0(
    "Error happens when you try to execute command ENV[\"R_HOME\"] = ",
    "\"/usr/lib/R\";Base.include(Main,\"/x/JuliaCall/julia/setup.jl\") in Julia."
  )
  expect_true(is_juliacall_setup_error(raw))
  expect_false(is_juliacall_setup_error("Julia is not found."))

  msg <- juliacall_setup_error_message(raw)
  expect_match(msg, "printed just above")
  expect_match(msg, "cs_install_julia(force = TRUE)", fixed = TRUE)
  expect_no_match(msg, "install_github")
  expect_match(msg, "conda")
  expect_match(msg, "Restart R")
  expect_match(msg, raw, fixed = TRUE)
})

test_that("run_julia_setup rewrites JuliaCall's errors", {
  local_mocked_bindings(
    julia_setup = function(...) stop(paste0(
      "Error happens when you try to execute command ",
      "Base.include(Main,\"setup.jl\") in Julia.")),
    .package = "JuliaCall"
  )
  expect_error(run_julia_setup(list()), "could not finish connecting")

  local_mocked_bindings(julia_setup = function(...) stop("Julia is not found."),
                        .package = "JuliaCall")
  expect_error(run_julia_setup(list()), "cs_install_julia()", fixed = TRUE)

  local_mocked_bindings(julia_setup = function(...) stop("something else"),
                        .package = "JuliaCall")
  expect_error(run_julia_setup(list()), "^something else$")
})
