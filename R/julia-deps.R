#' Run Julia as a Child Process, Without R's Library Paths
#'
#' On Linux, R puts its own library directories on `LD_LIBRARY_PATH` for
#' every child process (see `R_HOME/etc/ldpaths`), typically including
#' `/usr/lib/x86_64-linux-gnu`. A Julia started with that path loads the
#' system's versions of libraries it bundles itself, and can crash: on Ubuntu
#' with R 4.6 and Julia 1.13, Julia's package manager segfaults while
#' installing its registry. So remove it for the child; other platforms are
#' unaffected.
#'
#' @param julia_bin Path to the Julia executable.
#' @param script Path to a Julia script to run.
#' @param script_args Character arguments for the script.
#' @param quiet Logical. If `TRUE`, capture output (returned for error
#'   messages) instead of printing it.
#' @return List with `status` (integer exit status) and `output` (captured
#'   lines, or `character(0)` when not quiet).
#' @noRd
run_julia_script <- function(julia_bin, script, script_args = character(),
                             quiet = TRUE) {
  if (Sys.info()[["sysname"]] == "Linux") {
    old <- Sys.getenv("LD_LIBRARY_PATH", unset = NA)
    Sys.unsetenv("LD_LIBRARY_PATH")
    on.exit(if (!is.na(old)) Sys.setenv(LD_LIBRARY_PATH = old), add = TRUE)
  }
  args <- c("--startup-file=no", shQuote(script), shQuote(script_args))
  if (quiet) {
    out <- suppressWarnings(system2(julia_bin, args, stdout = TRUE,
                                    stderr = TRUE))
    status <- attr(out, "status")
    list(status = if (is.null(status)) 0L else as.integer(status),
         output = as.character(out))
  } else {
    status <- suppressWarnings(system2(julia_bin, args))
    list(status = as.integer(status), output = character(0))
  }
}


#' Install the Julia Packages circuitscaper and JuliaCall Need
#'
#' Runs JuliaCall's own dependency script (which installs RCall.jl and
#' Suppressor.jl, building RCall against this R), and optionally installs
#' further packages, in a child Julia process with a clean library path (see
#' [run_julia_script()]). [cs_setup()] then starts JuliaCall with
#' `install = FALSE`, so JuliaCall doesn't rerun the script itself, with R's
#' library path.
#'
#' @param julia_bin Path to the Julia executable.
#' @param packages Character. Further Julia packages to add, e.g.
#'   `c("Circuitscape", "Omniscape")`.
#' @param update Logical. Also update `packages` to their latest versions.
#' @param quiet Logical. Hide Julia's output unless something fails.
#' @return `TRUE` invisibly. Stops with Julia's output on failure.
#' @noRd
install_julia_dependencies <- function(julia_bin, packages = character(),
                                       update = FALSE, quiet = TRUE) {
  script <- system.file("julia", "install_dependency.jl", package = "JuliaCall")
  if (!nzchar(script)) {
    stop("Could not find JuliaCall's install_dependency.jl.", call. = FALSE)
  }
  res <- run_julia_script(julia_bin, script, R.home(), quiet = quiet)
  check_julia_script(res, "installing JuliaCall's Julia packages (RCall.jl ",
                     "and Suppressor.jl)")

  if (length(packages) > 0) {
    pkg_script <- tempfile(fileext = ".jl")
    on.exit(unlink(pkg_script), add = TRUE)
    pkg_vector <- paste0("[", paste0('"', packages, '"', collapse = ", "), "]")
    writeLines(c(
      "using Pkg",
      paste0("Pkg.add(", pkg_vector, ")"),
      if (update) paste0("Pkg.update(", pkg_vector, ")"),
      "Pkg.precompile()"
    ), pkg_script)
    res <- run_julia_script(julia_bin, pkg_script, quiet = quiet)
    check_julia_script(res, "installing ", paste(packages, collapse = " and "))
  }
  invisible(TRUE)
}


#' Stop if a Julia Child Process Failed
#' @param res As from [run_julia_script()].
#' @param ... Pasted together to describe the step.
#' @noRd
check_julia_script <- function(res, ...) {
  if (identical(res$status, 0L)) return(invisible(TRUE))
  what <- paste0(...)
  detail <- if (length(res$output)) {
    paste0("Julia's output (last lines):\n",
           paste(utils::tail(res$output, 25), collapse = "\n"))
  } else {
    "See Julia's output above."
  }
  crashed <- res$status %in% c(139L, -11L) # SIGSEGV
  stop(
    "Julia failed while ", what, " (exit status ", res$status,
    if (crashed) ", a crash" else "", ").\n", detail, "\n\n",
    "If this was a network problem, try again. Otherwise, restart R and run ",
    "cs_install_julia() again; if it keeps failing, please report it at ",
    "https://github.com/matthewkling/circuitscaper/issues with this output.",
    call. = FALSE
  )
}
