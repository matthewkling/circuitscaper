#' Evaluate Julia Code
#'
#' All Julia evaluation goes through here. Julia runs in its own process,
#' started and connected to by 'JuliaConnectoR', rather than inside R.
#' Keeping Julia out of R's process means the libraries R has loaded (for
#' example the system GDAL and libtiff that terra uses on Linux) can't clash
#' with the ones Julia's packages bundle.
#'
#' @param expr Character. Julia code.
#' @return The result, translated to R by 'JuliaConnectoR' (`NULL`
#'   invisibly for `nothing`).
#' @noRd
jl_eval <- function(expr) {
  JuliaConnectoR::juliaEval(expr)
}


#' A Julia String Literal
#'
#' @param x Character scalar, e.g. a file path.
#' @return Character: `x` quoted and escaped for Julia source code.
#' @noRd
jl_string <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("$", "\\$", x, fixed = TRUE)
  paste0("\"", x, "\"")
}


#' Start Julia
#'
#' Points 'JuliaConnectoR' at the Julia that `find_julia_bin()` found (via
#' `JULIA_BINDIR`, which 'JuliaConnectoR' reads when it starts Julia) and
#' starts it. 'JuliaConnectoR' starts Julia lazily, on the first evaluation;
#' if Julia is already running (e.g., another package started it), this
#' connects to that Julia instead, which [cs_setup()] then checks.
#'
#' @param julia_bin Path to the Julia executable.
#' @param quiet Logical. Suppress 'JuliaConnectoR''s startup messages.
#' @param julia_home The `julia_home` the user gave, or `NULL`, for the
#'   not-found message.
#' @return `TRUE` invisibly.
#' @noRd
start_julia <- function(julia_bin, quiet = TRUE, julia_home = NULL) {
  Sys.setenv(JULIA_BINDIR = dirname(julia_bin))
  start <- function() jl_eval("nothing")
  tryCatch(
    if (quiet) suppressMessages(start()) else start(),
    error = function(e) {
      stop(
        "Julia (", julia_bin, ") could not be started from R.\n",
        conditionMessage(e), "\n\n",
        "If Julia works from a terminal, restart R and try again. Otherwise, ",
        "run cs_install_julia(force = TRUE) to install a fresh copy.",
        call. = FALSE
      )
    }
  )
  invisible(TRUE)
}


#' Is a Julia Package Installed?
#' @param pkg Character package name.
#' @return Logical.
#' @noRd
jl_package_installed <- function(pkg) {
  isTRUE(jl_eval(paste0("Base.find_package(", jl_string(pkg),
                        ") !== nothing")))
}
