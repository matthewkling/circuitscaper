# Tests for running Julia child processes to install packages. A fake julia
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

  install_julia_dependencies(fake$bin)
  calls <- readLines(fake$log)
  expect_true("LD_LIBRARY_PATH=<unset>" %in% calls)
  expect_false(any(grepl("x86_64-linux-gnu", calls)))
  # ... and it's restored for R afterwards
  expect_identical(Sys.getenv("LD_LIBRARY_PATH"),
                   "/opt/R/lib:/usr/lib/x86_64-linux-gnu")
})

test_that("JuliaCall's dependency script runs with this R's R_HOME", {
  skip_on_os("windows")
  fake <- fake_recording_julia()
  install_julia_dependencies(fake$bin)
  args_line <- grep("^ARGS=", readLines(fake$log), value = TRUE)
  expect_length(args_line, 1)
  expect_match(args_line, "install_dependency.jl", fixed = TRUE)
  expect_match(args_line, R.home(), fixed = TRUE)
})

test_that("extra packages are added (and updated on request) in a script", {
  skip_on_os("windows")
  fake <- fake_recording_julia()
  install_julia_dependencies(fake$bin, packages = c("Circuitscape", "Omniscape"),
                             update = TRUE)
  calls <- readLines(fake$log)
  expect_length(grep("^ARGS=", calls), 2)
  expect_true('Pkg.add(["Circuitscape", "Omniscape"])' %in% calls)
  expect_true('Pkg.update(["Circuitscape", "Omniscape"])' %in% calls)

  fake2 <- fake_recording_julia()
  install_julia_dependencies(fake2$bin, packages = "Circuitscape")
  expect_false(any(grepl("Pkg.update", readLines(fake2$log))))
})

test_that("a failing Julia child process stops with its output", {
  skip_on_os("windows")
  fake <- fake_recording_julia(status = 139L)
  expect_error(install_julia_dependencies(fake$bin),
               "exit status 139, a crash")
  expect_error(install_julia_dependencies(fake$bin), "some julia output",
               fixed = TRUE)
})

test_that("cs_setup tells JuliaCall not to install dependencies itself", {
  skip_on_os("windows")
  skip_on_cran()
  skip_if(.cs_env$julia_ready, "Julia is already running in this session")
  fake <- fake_recording_julia()
  # A fake julia that passes the version check
  writeLines(c("#!/bin/sh", "echo 'julia version 1.12.1'"),
             file.path(dirname(fake$bin), "julia"))
  seen <- NULL
  local_mocked_bindings(
    install_julia_dependencies = function(...) invisible(TRUE)
  )
  local_mocked_bindings(
    julia_setup = function(...) { seen <<- list(...); stop("stop here") },
    .package = "JuliaCall"
  )
  expect_error(suppressMessages(cs_setup(julia_home = dirname(fake$bin))),
               "stop here")
  expect_false(seen$install)
  expect_false(seen$installJulia)
})
