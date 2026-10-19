# Tests for locating Julia without starting it. These use fake installs in
# temp directories, so they run whether or not Julia is installed.

# Set environment variables (NA = unset). Returns a function that restores
# the previous values, for use with on.exit().
set_envvars <- function(...) {
  apply_vals <- function(vals) {
    for (nm in names(vals)) {
      if (is.na(vals[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv, vals[nm])
    }
  }
  new <- list(...)
  old <- as.list(Sys.getenv(names(new), unset = NA, names = TRUE))
  apply_vals(new)
  function() apply_vals(old)
}

# Create a fake Julia install and return its bin/ directory.
fake_julia <- function() {
  bin_dir <- file.path(tempfile("julia_"), "bin")
  dir.create(bin_dir, recursive = TRUE)
  exe <- if (.Platform$OS.type == "windows") "julia.exe" else "julia"
  file.create(file.path(bin_dir, exe))
  bin_dir
}

expected_bin <- function(bin_dir) {
  exe <- if (.Platform$OS.type == "windows") "julia.exe" else "julia"
  normalizePath(file.path(bin_dir, exe), mustWork = FALSE)
}

test_that("find_julia_bin() honors the JULIA_HOME environment variable", {
  bin_dir <- fake_julia()
  old_opt <- options(JULIA_HOME = NULL)
  on.exit(options(old_opt), add = TRUE)
  restore <- set_envvars(JULIA_HOME = bin_dir)
  on.exit(restore(), add = TRUE)

  expect_identical(find_julia_bin(login_shell = FALSE), expected_bin(bin_dir))
})

test_that("find_julia_bin() honors the JULIA_HOME option before the env var", {
  opt_dir <- fake_julia()
  env_dir <- fake_julia()
  old_opt <- options(JULIA_HOME = opt_dir)
  on.exit(options(old_opt), add = TRUE)
  restore <- set_envvars(JULIA_HOME = env_dir)
  on.exit(restore(), add = TRUE)

  expect_identical(find_julia_bin(login_shell = FALSE), expected_bin(opt_dir))
})

test_that("find_julia_bin() finds a Julia recorded by JuliaCall::install_julia()", {
  # install_julia() installs outside the PATH and records the bin/ directory
  # in <depot>/prefs/JuliaCall; this is the case that used to fail.
  bin_dir <- fake_julia()
  depot <- tempfile("depot_")
  dir.create(file.path(depot, "prefs"), recursive = TRUE)
  cat(bin_dir, file = file.path(depot, "prefs", "JuliaCall"))

  old_opt <- options(JULIA_HOME = NULL)
  on.exit(options(old_opt), add = TRUE)
  restore <- set_envvars(JULIA_HOME = NA, JULIA_DEPOT_PATH = depot,
                PATH = tempfile("empty_path_"))
  on.exit(restore(), add = TRUE)

  expect_identical(find_julia_bin(login_shell = FALSE), expected_bin(bin_dir))
})

test_that("find_julia_bin() uses the first entry of a multi-entry depot path", {
  bin_dir <- fake_julia()
  depot <- tempfile("depot_")
  dir.create(file.path(depot, "prefs"), recursive = TRUE)
  cat(bin_dir, file = file.path(depot, "prefs", "JuliaCall"))

  old_opt <- options(JULIA_HOME = NULL)
  on.exit(options(old_opt), add = TRUE)
  restore <- set_envvars(JULIA_HOME = NA,
                JULIA_DEPOT_PATH = paste0(depot, .Platform$path.sep),
                PATH = tempfile("empty_path_"))
  on.exit(restore(), add = TRUE)

  expect_identical(find_julia_bin(login_shell = FALSE), expected_bin(bin_dir))
})

test_that("find_julia_bin() returns NULL when nothing is found", {
  skip_on_os("windows") # LOCALAPPDATA may hold a real install
  old_opt <- options(JULIA_HOME = NULL)
  on.exit(options(old_opt), add = TRUE)
  restore <- set_envvars(JULIA_HOME = NA, JULIA_DEPOT_PATH = tempfile("depot_"),
                PATH = tempfile("empty_path_"))
  on.exit(restore(), add = TRUE)

  expect_null(find_julia_bin(login_shell = FALSE))
})

test_that("find_julia_bin() ignores a stale install record", {
  skip_on_os("windows")
  depot <- tempfile("depot_")
  dir.create(file.path(depot, "prefs"), recursive = TRUE)
  cat(file.path(tempfile("gone_"), "bin"),
      file = file.path(depot, "prefs", "JuliaCall"))

  old_opt <- options(JULIA_HOME = NULL)
  on.exit(options(old_opt), add = TRUE)
  restore <- set_envvars(JULIA_HOME = NA, JULIA_DEPOT_PATH = depot,
                PATH = tempfile("empty_path_"))
  on.exit(restore(), add = TRUE)

  expect_null(find_julia_bin(login_shell = FALSE))
})

test_that("cs_setup() fails cleanly when no Julia can be found", {
  skip_if(.cs_env$julia_ready, "Julia is already running in this session")
  old_opt <- options(JULIA_HOME = NULL)
  on.exit(options(old_opt), add = TRUE)
  restore <- set_envvars(JULIA_HOME = NA, JULIA_DEPOT_PATH = tempfile("depot_"),
                         PATH = tempfile("empty_path_"))
  on.exit(restore(), add = TRUE)
  skip_if(!is.null(find_julia_bin()), "a Julia install is still reachable")

  expect_no_warning(
    expect_error(suppressMessages(cs_setup()), "cs_install_julia()", fixed = TRUE)
  )
})

test_that("cs_setup() gives a specific error for a bad julia_home", {
  skip_if(.cs_env$julia_ready, "Julia is already running in this session")

  expect_error(
    suppressMessages(cs_setup(julia_home = file.path(tempfile("nope_"), "bin"))),
    "Julia not found at julia_home"
  )
})

test_that("julia_not_found_message() points to cs_install_julia()", {
  expect_match(julia_not_found_message(), "cs_install_julia()", fixed = TRUE)
  expect_match(julia_not_found_message("/x/bin"), "/x/bin", fixed = TRUE)
})
