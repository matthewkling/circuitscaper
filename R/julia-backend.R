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


#' Stop Julia
#'
#' Ends the Julia process 'JuliaConnectoR' started. The next evaluation
#' starts a new one.
#' @noRd
jl_stop <- function() {
  tryCatch(JuliaConnectoR::stopJulia(), error = function(e) NULL)
  invisible()
}


#' Mark the Running Julia as Set Up by circuitscaper
#'
#' Defines a marker in Julia's `Main` module, which [cs_setup()] checks to
#' tell whether the Julia it set up is still the one running.
#' @noRd
mark_julia_ready <- function() {
  jl_eval("global circuitscaper_ready__ = true; nothing")
  invisible()
}


#' Is the Julia circuitscaper Set Up Still Running?
#'
#' circuitscaper records when it has set up Julia, but the Julia process can
#' go away afterwards: it can crash (e.g., run out of memory), or be stopped
#' with `JuliaConnectoR::stopJulia()`. 'JuliaConnectoR' then starts a new,
#' bare Julia on the next evaluation (or, if the old connection is broken,
#' fails), so the record alone can't be trusted.
#'
#' @return `"ready"` (the Julia circuitscaper set up), `"fresh"` (a Julia
#'   without circuitscaper's setup), or `"broken"` (no working connection).
#' @noRd
julia_session_state <- function() {
  tryCatch(
    if (isTRUE(suppressMessages(
      jl_eval("isdefined(Main, :circuitscaper_ready__)")))) {
      "ready"
    } else {
      "fresh"
    },
    error = function(e) "broken"
  )
}


#' Forget circuitscaper's Julia Setup
#'
#' @param stop Logical. Also stop the Julia process.
#' @noRd
forget_julia <- function(stop = TRUE) {
  if (stop) jl_stop()
  .cs_env$julia_ready <- FALSE
  .cs_env$loaded_packages <- character(0)
  .cs_env$julia_threads <- 1L
  .cs_env$julia_interactive <- 0L
  invisible()
}


#' Is a Julia Package Installed?
#' @param pkg Character package name.
#' @return Logical.
#' @noRd
jl_package_installed <- function(pkg) {
  isTRUE(jl_eval(paste0("Base.find_package(", jl_string(pkg),
                        ") !== nothing")))
}
