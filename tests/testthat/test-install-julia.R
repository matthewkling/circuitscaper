# Tests for circuitscaper's own Julia installer. The end-to-end tests
# install a fake Julia from a local release index and archive (file:// URLs),
# into a temporary user data directory, so they need no network or Julia.

# A minimal versions.json-like index, with the cases selection must handle
fixture_versions <- function() {
  f <- function(version, triplet, os, arch, ext, kind = "archive") {
    list(triplet = triplet, os = os, arch = arch, version = version,
         kind = kind, extension = ext, size = 1, sha256 = "x",
         url = paste0("https://example.org/julia-", version, "-", triplet,
                      ".", ext))
  }
  platform_files <- function(v) list(
    f(v, "x86_64-linux-musl", "linux", "x86_64", "tar.gz"),
    f(v, "x86_64-linux-gnu", "linux", "x86_64", "tar.gz"),
    f(v, "aarch64-linux-gnu", "linux", "aarch64", "tar.gz"),
    f(v, "aarch64-apple-darwin14", "mac", "aarch64", "dmg"),
    f(v, "aarch64-apple-darwin14", "mac", "aarch64", "tar.gz"),
    f(v, "x86_64-apple-darwin14", "mac", "x86_64", "tar.gz"),
    f(v, "x86_64-w64-mingw32", "winnt", "x86_64", "exe", kind = "installer"),
    f(v, "x86_64-w64-mingw32", "winnt", "x86_64", "zip"),
    f(v, "i686-w64-mingw32", "winnt", "i686", "zip")
  )
  list(
    "1.9.4" = list(stable = TRUE, files = platform_files("1.9.4")),
    "1.12.1" = list(stable = TRUE, files = platform_files("1.12.1")),
    "1.10.10" = list(stable = TRUE, files = platform_files("1.10.10")),
    "1.13.0-rc1" = list(stable = FALSE, files = platform_files("1.13.0-rc1"))
  )
}

test_that("'latest' is the newest stable release, compared as versions", {
  # Alphabetically "1.9.4" > "1.12.1"; the prerelease must be skipped too
  file <- select_julia_file(fixture_versions(), "latest", "linux", "x86_64")
  expect_identical(file$version, "1.12.1")
})

test_that("the portable archive for each platform is chosen", {
  v <- fixture_versions()
  pick <- function(os, arch) select_julia_file(v, "1.12.1", os, arch)$triplet

  expect_identical(pick("linux", "x86_64"), "x86_64-linux-gnu") # not musl
  expect_identical(pick("linux", "aarch64"), "aarch64-linux-gnu")
  expect_identical(pick("mac", "aarch64"), "aarch64-apple-darwin14")
  expect_identical(select_julia_file(v, "1.12.1", "mac", "aarch64")$extension,
                   "tar.gz") # not the .dmg
  expect_identical(pick("winnt", "x86_64"), "x86_64-w64-mingw32")
  expect_identical(select_julia_file(v, "1.12.1", "winnt", "x86_64")$extension,
                   "zip") # not the .exe installer
})

test_that("unknown versions and platforms give clear errors", {
  v <- fixture_versions()
  expect_error(select_julia_file(v, "9.9.9", "linux", "x86_64"),
               "Julia 9.9.9 was not found")
  expect_error(select_julia_file(v, "1.12.1", "winnt", "aarch64"),
               "no download for this platform")
  expect_error(select_julia_file(v, "1.12.1", "freebsd", "x86_64"),
               "julialang.org/install")
})

test_that("julia_platform reports an os and arch versions.json uses", {
  p <- julia_platform()
  expect_true(p$os %in% c("linux", "mac", "winnt"))
  expect_false(p$arch %in% c("arm64", "amd64"))
})


# --- End-to-end install from a local fake release ---------------------------

# Build a fake Julia archive for this platform and a release index pointing
# at it. Returns the index path.
fake_release <- function(version, dir = tempfile("release_"),
                         corrupt_size = FALSE) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  p <- julia_platform()
  build <- file.path(dir, "build")
  bin <- file.path(build, paste0("julia-", version), "bin")
  dir.create(bin, recursive = TRUE)
  exe <- file.path(bin, julia_exe())
  writeLines(c("#!/bin/sh", paste0("echo 'julia version ", version, "'")), exe)
  Sys.chmod(exe, "755")

  windows <- p$os == "winnt"
  ext <- if (windows) "zip" else "tar.gz"
  archive <- file.path(dir, paste0("julia-", version, ".", ext))
  old_wd <- setwd(build)
  on.exit(setwd(old_wd), add = TRUE)
  if (windows) {
    utils::zip(archive, paste0("julia-", version), flags = "-r9Xq")
  } else {
    utils::tar(archive, paste0("julia-", version), compression = "gzip")
  }

  triplet <- switch(p$os,
                    linux = paste0(p$arch, "-linux-gnu"),
                    mac = paste0(p$arch, "-apple-darwin14"),
                    winnt = paste0(p$arch, "-w64-mingw32"))
  sha256sum <- get0("sha256sum", envir = asNamespace("tools"),
                    mode = "function", inherits = FALSE)
  entry <- list(
    stable = TRUE,
    files = list(list(
      triplet = triplet, os = p$os, arch = p$arch, version = version,
      kind = "archive", extension = ext,
      size = file.size(archive) + if (corrupt_size) 1 else 0,
      sha256 = if (is.null(sha256sum)) "unchecked" else unname(sha256sum(archive)),
      url = paste0("file://", normalizePath(archive, winslash = "/"))
    ))
  )
  versions <- stats::setNames(list(entry), version)
  index <- file.path(dir, "versions.json")
  writeLines(rjson::toJSON(versions), index)
  index
}

# Point the installer at a fake index and a temporary user data directory,
# for the rest of the calling test
local_fake_install_env <- function(index, env = parent.frame()) {
  data_dir <- withr::local_tempfile(pattern = "userdata_", .local_envir = env)
  withr::local_options(
    circuitscaper.julia_versions_url =
      paste0("file://", normalizePath(index, winslash = "/", mustWork = FALSE)),
    .local_envir = env
  )
  withr::local_envvar(R_USER_DATA_DIR = data_dir, .local_envir = env)
  invisible(data_dir)
}

test_that("install_julia_binary installs a release where cs_setup finds it", {
  skip_on_os("windows") # the fake julia is a shell script
  index <- fake_release("1.12.1")
  local_fake_install_env(index)

  bin_dir <- suppressMessages(install_julia_binary("latest"))
  expect_true(startsWith(normalizePath(bin_dir),
                         normalizePath(julia_install_root())))
  expect_identical(installed_julia_bin(),
                   normalizePath(file.path(bin_dir, julia_exe())))
  expect_equal(julia_version(installed_julia_bin()), package_version("1.12.1"))

  # find_julia_bin() prefers it over JuliaCall's (possibly stale) record
  depot <- withr::local_tempfile(pattern = "depot_")
  dir.create(file.path(depot, "prefs"), recursive = TRUE)
  stale <- file.path(withr::local_tempfile(pattern = "stale_"), "bin")
  dir.create(stale, recursive = TRUE)
  file.create(file.path(stale, julia_exe()))
  cat(stale, file = file.path(depot, "prefs", "JuliaCall"))
  withr::local_options(JULIA_HOME = NULL)
  withr::local_envvar(JULIA_HOME = NA, JULIA_DEPOT_PATH = depot)
  expect_identical(find_julia_bin(login_shell = FALSE), installed_julia_bin())
})

test_that("installing a new version replaces the old one", {
  skip_on_os("windows")
  dir <- tempfile("release_")
  local_fake_install_env(fake_release("1.10.10", dir = file.path(dir, "a")))
  suppressMessages(install_julia_binary("latest"))
  expect_equal(julia_version(installed_julia_bin()), package_version("1.10.10"))

  withr::local_options(circuitscaper.julia_versions_url = paste0(
    "file://", normalizePath(fake_release("1.12.1", dir = file.path(dir, "b")),
                             winslash = "/")))
  suppressMessages(install_julia_binary("latest"))
  expect_equal(julia_version(installed_julia_bin()), package_version("1.12.1"))
  expect_identical(list.files(julia_install_root()), "1.12.1")
})

test_that("a corrupt download is rejected and nothing is installed", {
  index <- fake_release("1.12.1", corrupt_size = TRUE)
  local_fake_install_env(index)
  expect_error(suppressMessages(install_julia_binary("latest")),
               "incomplete or corrupt")
  expect_null(installed_julia_bin())
})

test_that("an unreachable release index gives a helpful error", {
  local_fake_install_env(file.path(tempfile(), "missing.json"))
  expect_error(suppressWarnings(install_julia_binary("latest")),
               "Could not download the index of Julia releases")
})
