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

# A fake Julia install with Julia's layout: bin/julia and lib/julia/libunwind
fake_julia_layout <- function(env = parent.frame()) {
  root <- withr::local_tempfile(pattern = "julialayout_", .local_envir = env)
  dir.create(file.path(root, "bin"), recursive = TRUE)
  dir.create(file.path(root, "lib", "julia"), recursive = TRUE)
  file.create(file.path(root, "bin", "julia"))
  for (f in c("libunwind.so", "libunwind.so.8", "libunwind.so.8.2.0")) {
    file.create(file.path(root, "lib", "julia", f))
  }
  root
}

test_that("Julia's libunwind is preloaded into R on Linux", {
  skip_on_os(c("windows", "mac", "solaris"))
  root <- fake_julia_layout()
  loaded <- character(0)
  local_mocked_bindings(load_shared_library = function(path) {
    loaded <<- c(loaded, path)
  })
  old <- .cs_env$libunwind
  on.exit(.cs_env$libunwind <- old, add = TRUE)
  .cs_env$libunwind <- NULL

  lib <- preload_julia_libunwind(file.path(root, "bin", "julia"))
  expect_identical(lib, normalizePath(file.path(root, "lib", "julia",
                                                "libunwind.so")))
  expect_identical(loaded, lib)

  # Only once per session
  preload_julia_libunwind(file.path(root, "bin", "julia"))
  expect_length(loaded, 1)
})

test_that("a failed preload warns rather than stopping setup", {
  skip_on_os(c("windows", "mac", "solaris"))
  root <- fake_julia_layout()
  local_mocked_bindings(load_shared_library = function(path) stop("nope"))
  old <- .cs_env$libunwind
  on.exit(.cs_env$libunwind <- old, add = TRUE)
  .cs_env$libunwind <- NULL
  expect_warning(preload_julia_libunwind(file.path(root, "bin", "julia")),
                 "Could not preload Julia's libunwind")
  expect_null(.cs_env$libunwind)
})

test_that("nothing is preloaded off Linux or without a libunwind", {
  root <- withr::local_tempfile(pattern = "nolib_")
  dir.create(file.path(root, "bin"), recursive = TRUE)
  dir.create(file.path(root, "lib", "julia"), recursive = TRUE)
  file.create(file.path(root, "bin", "julia"))
  local_mocked_bindings(load_shared_library = function(path) stop("called"))
  expect_null(preload_julia_libunwind(file.path(root, "bin", "julia")))
})

test_that("with_ld_preload sets LD_PRELOAD only while evaluating", {
  withr::local_envvar(LD_PRELOAD = NA)
  seen <- with_ld_preload("/x/libunwind.so", Sys.getenv("LD_PRELOAD"))
  expect_identical(seen, "/x/libunwind.so")
  expect_identical(Sys.getenv("LD_PRELOAD", unset = "<unset>"), "<unset>")

  withr::local_envvar(LD_PRELOAD = "/other.so")
  seen <- with_ld_preload("/x/libunwind.so", Sys.getenv("LD_PRELOAD"))
  expect_identical(seen, "/x/libunwind.so /other.so")
  expect_identical(Sys.getenv("LD_PRELOAD"), "/other.so")
  expect_identical(with_ld_preload(NULL, 42), 42)
})
