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
    "or update your Julia installation (e.g., with juliaup). If you set ",
    "JULIA_HOME, point it at the new Julia or unset it.",
    call. = FALSE
  )
}


#' Stop if the Julia Running in This R Session Is Too Old
#'
#' Covers a Julia started earlier in the session (e.g., by a failed setup
#' attempt or by `JuliaCall::julia_setup()` directly), which
#' `JuliaCall::julia_setup()` reuses rather than replacing.
#'
#' @return `NULL` invisibly. Called for its error.
#' @noRd
check_running_julia_version <- function() {
  v <- tryCatch(
    package_version(sub("[-+].*$", "",
                        JuliaCall::julia_eval("string(VERSION)"))),
    error = function(e) NULL
  )
  if (is.null(v) || v >= min_julia_version()) return(invisible(NULL))
  stop(
    "Julia ", v, " is running in this R session, but circuitscaper ",
    "requires Julia >= ", min_julia_version(), ". A running Julia can't be ",
    "replaced, so restart R, then run cs_install_julia(force = TRUE) if ",
    "you don't yet have a newer Julia.",
    call. = FALSE
  )
}
