#' Index of Official Julia Releases
#'
#' @return Character URL of `versions.json`, which lists every Julia release
#'   with download URLs, sizes, and SHA-256 checksums for each platform.
#' @noRd
julia_versions_url <- function() {
  getOption("circuitscaper.julia_versions_url",
            "https://julialang-s3.julialang.org/bin/versions.json")
}


#' Where circuitscaper Installs Julia
#'
#' A subdirectory of circuitscaper's user data directory (see
#' [tools::R_user_dir()]), so installs don't write to other packages'
#' directories or to the Julia depot.
#'
#' @return Character path.
#' @noRd
julia_install_root <- function() {
  file.path(tools::R_user_dir("circuitscaper", which = "data"), "julia")
}


#' Julia Installed by cs_install_julia(), If Any
#'
#' @return Path to the Julia executable of the newest version under
#'   [julia_install_root()], or `NULL`.
#' @noRd
installed_julia_bin <- function() {
  root <- julia_install_root()
  if (!dir.exists(root)) return(NULL)
  dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  versions <- lapply(basename(dirs), function(v) {
    tryCatch(package_version(v), error = function(e) NULL)
  })
  ok <- !vapply(versions, is.null, logical(1))
  if (!any(ok)) return(NULL)
  dirs <- dirs[ok]
  versions <- do.call(c, versions[ok])
  for (d in dirs[order(versions, decreasing = TRUE)]) {
    bin <- file.path(d, "bin", julia_exe())
    if (file.exists(bin)) return(normalizePath(bin, mustWork = FALSE))
  }
  NULL
}


#' Platform of This R Session, in versions.json Terms
#'
#' Julia runs inside the R process, so its architecture must match R's (not
#' necessarily the machine's: e.g., x86_64 R under Rosetta on Apple silicon
#' needs x86_64 Julia).
#'
#' @return List with `os` ("linux", "mac", or "winnt") and `arch` (e.g.
#'   "x86_64", "aarch64").
#' @noRd
julia_platform <- function() {
  sysname <- Sys.info()[["sysname"]]
  os <- switch(sysname, Linux = "linux", Darwin = "mac", Windows = "winnt",
               tolower(sysname))
  arch <- R.version$arch
  arch <- switch(arch, arm64 = "aarch64", amd64 = "x86_64", arch)
  list(os = os, arch = arch)
}


#' Pick the Julia Release and Download for a Platform
#'
#' Pure function of the parsed `versions.json`, so it can be tested without
#' network access.
#'
#' @param versions Parsed `versions.json`: a named list (names are version
#'   numbers) of entries with `stable` and `files`.
#' @param version `"latest"` for the newest stable release, or a version
#'   number such as `"1.12.1"`.
#' @param os,arch As from [julia_platform()].
#' @return The file entry (a list with `url`, `sha256`, `size`, `version`,
#'   ...) for a portable archive: `.tar.gz` on Linux (glibc builds only, not
#'   musl) and macOS (not the `.dmg`), `.zip` on Windows.
#' @noRd
select_julia_file <- function(versions, version = "latest", os, arch) {
  if (identical(version, "latest")) {
    stable <- names(Filter(function(v) isTRUE(v$stable), versions))
    parsed <- lapply(stable, function(s) {
      tryCatch(package_version(s), error = function(e) NULL)
    })
    ok <- !vapply(parsed, is.null, logical(1))
    if (!any(ok)) {
      stop("No stable Julia release found in the release index.", call. = FALSE)
    }
    # Compare as versions, not strings ("1.12.1" > "1.9.4")
    stable <- stable[ok]
    version <- stable[order(do.call(c, parsed[ok]), decreasing = TRUE)][1]
  }
  entry <- versions[[version]]
  if (is.null(entry)) {
    stop("Julia ", version, " was not found in the release index of ",
         "Julia versions.", call. = FALSE)
  }

  triplet_ok <- switch(
    os,
    linux = function(t) identical(t, paste0(arch, "-linux-gnu")),
    mac = function(t) startsWith(t, paste0(arch, "-apple-darwin")),
    winnt = function(t) identical(t, paste0(arch, "-w64-mingw32")),
    function(t) FALSE
  )
  ext <- if (os == "winnt") "zip" else "tar.gz"
  files <- Filter(function(f) {
    identical(f$kind, "archive") && identical(f$extension, ext) &&
      triplet_ok(f$triplet)
  }, entry$files)

  if (length(files) == 0) {
    stop("Julia ", version, " has no download for this platform (",
         os, ", ", arch, "). Install Julia from ",
         "https://julialang.org/install/ instead, then run ",
         "cs_install_julia() to add the Julia packages.", call. = FALSE)
  }
  files[[1]]
}


#' Download, Verify, and Unpack Julia
#'
#' Installs into `julia_install_root()/<version>/`, replacing any Julia
#' previously installed there by circuitscaper. Nothing is replaced until the
#' download has been verified and unpacked.
#'
#' @param version `"latest"` or a version number.
#' @return Path to the installed Julia `bin/` directory, invisibly.
#' @noRd
install_julia_binary <- function(version = "latest") {
  platform <- julia_platform()

  index <- tempfile(fileext = ".json")
  on.exit(unlink(index), add = TRUE)
  download_or_stop(julia_versions_url(), index, "the index of Julia releases")
  versions <- rjson::fromJSON(file = index)

  file_info <- select_julia_file(versions, version, platform$os, platform$arch)
  version <- file_info$version

  archive <- tempfile(fileext = paste0(".", file_info$extension))
  on.exit(unlink(archive), add = TRUE)
  message("Downloading Julia ", version, " (",
          format(structure(file_info$size, class = "object_size"),
                 units = "auto"), ")...")
  download_or_stop(file_info$url, archive, paste("Julia", version))
  verify_download(archive, file_info)

  # Unpack into a staging directory next to the final location, then move,
  # so a failed unpack never leaves a half-installed Julia behind.
  root <- julia_install_root()
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  staging <- tempfile("staging_", tmpdir = root)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  message("Unpacking...")
  if (file_info$extension == "zip") {
    utils::unzip(archive, exdir = staging)
  } else {
    status <- utils::untar(archive, exdir = staging)
    if (!identical(as.integer(status), 0L)) {
      stop("Unpacking the Julia download failed.", call. = FALSE)
    }
  }

  # Archives hold a single top-level julia-<version>/ directory
  top <- list.dirs(staging, recursive = FALSE, full.names = TRUE)
  top <- top[file.exists(file.path(top, "bin", julia_exe()))]
  if (length(top) != 1) {
    stop("The Julia download did not have the expected layout ",
         "(julia-<version>/bin/julia).", call. = FALSE)
  }

  # Replace earlier circuitscaper-installed Julia versions only now.
  old <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  old <- old[!startsWith(basename(old), "staging_")]
  unlink(old, recursive = TRUE)
  dest <- file.path(root, version)
  if (!file.rename(top, dest)) {
    stop("Could not move Julia into place at ", dest, ".", call. = FALSE)
  }

  bin_dir <- normalizePath(file.path(dest, "bin"), mustWork = TRUE)
  message("Installed Julia ", version, " to ", dest)
  invisible(bin_dir)
}


#' Download a File, or Stop With an Informative Error
#' @noRd
download_or_stop <- function(url, destfile, what) {
  # Julia is a few hundred MB; R's default 60 s timeout is far too short
  old <- options(timeout = max(1800, getOption("timeout")))
  on.exit(options(old), add = TRUE)
  status <- tryCatch(
    utils::download.file(url, destfile, mode = "wb", quiet = TRUE),
    error = function(e) e,
    warning = function(w) w
  )
  if (inherits(status, "condition") || !identical(as.integer(status), 0L) ||
      !file.exists(destfile)) {
    detail <- if (inherits(status, "condition")) {
      paste0(": ", conditionMessage(status))
    } else {
      ""
    }
    stop("Could not download ", what, " from ", url, detail, "\n",
         "Check your internet connection and try again, or install Julia ",
         "from https://julialang.org/install/ and then run ",
         "cs_install_julia() to add the Julia packages.", call. = FALSE)
  }
  invisible(destfile)
}


#' Check a Download Against the Size and Checksum in versions.json
#'
#' Verifies the SHA-256 checksum where R provides it ([tools::sha256sum()],
#' R >= 4.5), and the file size otherwise.
#'
#' @param path Downloaded file.
#' @param file_info Its entry from versions.json.
#' @noRd
verify_download <- function(path, file_info) {
  size <- file.size(path)
  if (!is.null(file_info$size) && !identical(as.numeric(size),
                                             as.numeric(file_info$size))) {
    stop("The Julia download is incomplete or corrupt (", size, " bytes, ",
         "expected ", file_info$size, "). Please try again.", call. = FALSE)
  }
  sha256sum <- get0("sha256sum", envir = asNamespace("tools"),
                    mode = "function", inherits = FALSE)
  if (!is.null(sha256sum) && !is.null(file_info$sha256)) {
    actual <- unname(sha256sum(path))
    if (!identical(tolower(actual), tolower(file_info$sha256))) {
      stop("The Julia download failed its checksum test. Please try again.",
           call. = FALSE)
    }
  }
  invisible(TRUE)
}
