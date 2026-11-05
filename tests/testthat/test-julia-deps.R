# Tests for running Julia child processes to install packages, and for
# the helpers that talk to the running Julia. A fake julia
# (a shell script) records its arguments and environment, so these run
# without Julia.

# A fake julia that records how it was called, then exits with `status`.
# The script it is given to run is copied, so its contents can be checked.
fake_recording_julia <- function(status = 0L) {
  dir <- withr::local_tempfile(pattern = "fakejulia_", .local_envir = parent.frame())
  dir.create(file.path(dir, "bin"), recursive = TRUE)
  log <- file.path(dir, "calls.log")
  exe <- file.path(dir, "bin", "julia")
  writeLines(c(
    "#!/bin/sh",
    paste0("echo \"LD_LIBRARY_PATH=${LD_LIBRARY_PATH-<unset>}\" >> '", log, "'"),
    paste0("echo \"ARGS=$*\" >> '", log, "'"),
    paste0("cat \"$2\" >> '", log, "'"),
    "echo 'some julia output'",
    paste0("exit ", status)
  ), exe)
  Sys.chmod(exe, "755")
  list(bin = exe, log = log)
}

test_that("Julia child processes run without R's LD_LIBRARY_PATH on Linux", {
  skip_on_os(c("windows", "mac", "solaris"))
  fake <- fake_recording_julia()
  withr::local_envvar(LD_LIBRARY_PATH = "/opt/R/lib:/usr/lib/x86_64-linux-gnu")

  install_julia_packages(fake$bin, "Circuitscape")
  calls <- readLines(fake$log)
  expect_true("LD_LIBRARY_PATH=<unset>" %in% calls)
  expect_false(any(grepl("x86_64-linux-gnu", calls)))
  # ... and it's restored for R afterwards
  expect_identical(Sys.getenv("LD_LIBRARY_PATH"),
                   "/opt/R/lib:/usr/lib/x86_64-linux-gnu")
})

test_that("packages are added (and updated on request) in a script", {
  skip_on_os("windows")
  fake <- fake_recording_julia()
  install_julia_packages(fake$bin, c("Circuitscape", "Omniscape"),
                         update = TRUE)
  calls <- readLines(fake$log)
  expect_length(grep("^ARGS=", calls), 1)
  expect_true('Pkg.add(["Circuitscape", "Omniscape"])' %in% calls)
  expect_true('Pkg.update(["Circuitscape", "Omniscape"])' %in% calls)
  expect_true("Pkg.precompile()" %in% calls)

  fake2 <- fake_recording_julia()
  install_julia_packages(fake2$bin, "Circuitscape")
  expect_false(any(grepl("Pkg.update", readLines(fake2$log))))
})

test_that("the package list includes what JuliaConnectoR needs", {
  expect_setequal(julia_packages(), c("Circuitscape", "Omniscape", "Tables"))
})

test_that("a failing Julia child process stops with its output", {
  skip_on_os("windows")
  fake <- fake_recording_julia(status = 139L)
  expect_error(install_julia_packages(fake$bin, "Circuitscape"),
               "exit status 139, a crash")
  expect_error(install_julia_packages(fake$bin, "Circuitscape"),
               "some julia output", fixed = TRUE)
})

test_that("jl_string() quotes and escapes for Julia", {
  expect_identical(jl_string("/a/b.jl"), '"/a/b.jl"')
  expect_identical(jl_string("C:\\Users\\x"), '"C:\\\\Users\\\\x"')
  expect_identical(jl_string('say "hi" $x'), '"say \\"hi\\" \\$x"')
})

test_that("cs_setup starts the Julia it found via JuliaConnectoR", {
  skip_on_os("windows")
  skip_on_cran()
  skip_if(.cs_env$julia_ready, "Julia is already running in this session")
  fake <- fake_recording_julia()
  # A fake julia that passes the version check
  writeLines(c("#!/bin/sh", "echo 'julia version 1.12.1'"), fake$bin)
  withr::local_envvar(JULIA_BINDIR = NA)
  seen <- NULL
  local_mocked_bindings(jl_eval = function(expr) {
    seen <<- c(seen, expr)
    stop("stop here")
  })
  expect_error(suppressMessages(cs_setup(julia_home = dirname(fake$bin))),
               "could not be started")
  expect_identical(Sys.getenv("JULIA_BINDIR"), dirname(fake$bin))
  expect_length(seen, 1)
})

test_that("a missing Julia package is reported, not loaded", {
  local_mocked_bindings(jl_eval = function(expr) FALSE)
  expect_false(jl_package_installed("Circuitscape"))
  local_mocked_bindings(jl_eval = function(expr) {
    expect_match(expr, 'Base.find_package("Omniscape")', fixed = TRUE)
    TRUE
  })
  expect_true(jl_package_installed("Omniscape"))
})

test_that("local_clean_library_path() restores LD_LIBRARY_PATH on exit", {
  skip_on_os(c("windows", "mac", "solaris"))
  withr::local_envvar(LD_LIBRARY_PATH = "/opt/R/lib")
  inner <- function() {
    local_clean_library_path()
    Sys.getenv("LD_LIBRARY_PATH", unset = "<unset>")
  }
  expect_identical(inner(), "<unset>")
  expect_identical(Sys.getenv("LD_LIBRARY_PATH"), "/opt/R/lib")

  withr::local_envvar(LD_LIBRARY_PATH = NA)
  inner()
  expect_identical(Sys.getenv("LD_LIBRARY_PATH", unset = "<unset>"), "<unset>")
})
