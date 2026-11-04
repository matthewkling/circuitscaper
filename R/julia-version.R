#' Minimum Supported Julia Version
#'
#' Current releases of Circuitscape.jl, Omniscape.jl, and RCall.jl (which
#' JuliaCall uses) all require Julia 1.10. On older Julia, the package
#' manager silently falls back to old releases, which fail in obscure ways:
#' for example, RCall.jl releases from before 2025 call `SET_SYMVALUE`, which
#' R 4.6 no longer exports.
#'
#' @return A `package_version`.
#' @noRd
min_julia_version <- function() {
  package_version("1.10")
}


#' Parse the Output of `julia --version`
#'
#' @param output Character vector, e.g. `"julia version 1.12.1"` or
#'   `"julia version 1.13.0-DEV"`.
#' @return A `package_version`, or `NULL` if no version is found.
#' @noRd
parse_julia_version <- function(output) {
  m <- regmatches(output, regexpr("[0-9]+\\.[0-9]+(\\.[0-9]+)?", output))
  if (length(m) == 0) return(NULL)
  tryCatch(package_version(m[1]), error = function(e) NULL)
}


#' Version of a Julia Binary, Without Starting a Julia Session
#'
#' @param julia_bin Path to the Julia executable, or `NULL`.
#' @return A `package_version`, or `NULL` if it can't be determined.
#' @noRd
julia_version <- function(julia_bin) {
  if (is.null(julia_bin) || !nzchar(julia_bin)) return(NULL)
  out <- tryCatch(
    # timeout: a juliaup launcher may update itself or fetch a channel
    # first. On timeout the version is unknown, which doesn't block setup.
    suppressWarnings(system2(julia_bin, c("--startup-file=no", "--version"),
                             stdout = TRUE, stderr = FALSE, timeout = 60)),
    error = function(e) character(0)
  )
  parse_julia_version(out)
}


#' Stop if a Julia Binary Is Too Old
#'
#' Does nothing if the version can't be determined, leaving any problem to
#' surface when Julia starts.
#'
#' @param julia_bin Path to the Julia executable, or `NULL`.
#' @return `NULL` invisibly. Called for its error.
#' @noRd
check_julia_version <- function(julia_bin) {
  v <- julia_version(julia_bin)
  if (is.null(v) || v >= min_julia_version()) return(invisible(NULL))
  stop(
    "Julia ", v, " (at ", julia_bin, ") is too old; circuitscaper requires ",
    "Julia >= ", min_julia_version(), ".\n",
    "To install a current Julia, restart R and run:\n",
    "  cs_install_julia(force = TRUE)\n",
    "or update your Julia installation (e.g., with juliaup).\n",
    "If cs_install_julia() installed this Julia, your 'JuliaCall' is likely ",
    "the CRAN release, which installs Julia 1.9 by mistake. Install the ",
    "development version first:\n",
    "  remotes::install_github(\"JuliaInterop/JuliaCall\")",
    call. = FALSE
  )
}


#' Can the Installed JuliaCall Install Current Julia Versions?
#'
#' JuliaCall 0.17.6, the CRAN release as of this writing, has two bugs in
#' `install_julia()`: it finds the "latest" version by sorting version strings
#' alphabetically (so "1.9.4" beats "1.12.1"), and it builds the download URL
#' from the first three characters of the version (so "1.12.1" becomes
#' "1.1"). Together these mean it can't install any Julia from 1.10 on. Both
#' were fixed in a single commit on JuliaCall's GitHub, without a version
#' bump, so the installed version number can't tell the releases apart.
#' Instead, this checks whether `julia_latest_version()` contains the fix
#' (comparing versions with `numeric_version()`). The function is looked up
#' in JuliaCall's namespace rather than as an export, since it was only
#' exported (in September 2025) months after the fix.
#'
#' @param fun The function to inspect, or `NULL` to look it up. Exposed for
#'   testing.
#' @param version Installed JuliaCall version. Exposed for testing.
#' @return Logical. `TRUE` if the installed JuliaCall has the bugs.
#' @noRd
juliacall_install_is_outdated <- function(fun = NULL,
                                          version = utils::packageVersion("JuliaCall")) {
  # Any release after 0.17.6 postdates the fix; only inspect the code for
  # 0.17.6 itself, which is both the buggy CRAN release and the fixed
  # GitHub version. This keeps a future rewrite of julia_latest_version()
  # from being mistaken for the bug.
  if (version > "0.17.6") return(FALSE)
  if (is.null(fun)) {
    fun <- get0("julia_latest_version", envir = asNamespace("JuliaCall"),
                mode = "function", inherits = FALSE)
  }
  if (!is.function(fun)) return(TRUE)
  src <- paste(deparse(body(fun)), collapse = "\n")
  !grepl("numeric_version", src, fixed = TRUE)
}


#' Message for an Outdated JuliaCall
#' @noRd
juliacall_outdated_message <- function() {
  paste0(
    "Your 'JuliaCall' (", utils::packageVersion("JuliaCall"), ") can't ",
    "install current Julia versions: the CRAN release installs Julia 1.9, ",
    "which circuitscaper's Julia packages no longer support. Either:\n",
    "  * install the development version of 'JuliaCall', restart R, and run ",
    "cs_install_julia() again:\n",
    "      remotes::install_github(\"JuliaInterop/JuliaCall\")\n",
    "  * or install Julia >= ", min_julia_version(), " yourself (e.g., from ",
    "https://julialang.org/install/), then run cs_install_julia() to add ",
    "the Julia packages."
  )
}
