#' Run Julia as a Child Process, Without R's Library Paths
#'
#' On Linux, R puts its own library directories on `LD_LIBRARY_PATH` for
#' every child process (see `R_HOME/etc/ldpaths`), typically including
#' `/usr/lib/x86_64-linux-gnu`. A Julia started with that path loads the
#' system's versions of libraries it bundles itself, and can crash: on Ubuntu
#' with R 4.6 and Julia 1.13, Julia's package manager segfaults while
#' installing its registry. So remove it for the child; other platforms are
#' unaffected. ('JuliaConnectoR' does the same when it starts Julia.)
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
  local_clean_library_path()
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


#' Unset LD_LIBRARY_PATH Until the Calling Function Returns, on Linux
#'
#' See `run_julia_script()` for why.
#'
#' @param envir The calling function's environment.
#' @noRd
local_clean_library_path <- function(envir = parent.frame()) {
  if (Sys.info()[["sysname"]] != "Linux") return(invisible())
  old <- Sys.getenv("LD_LIBRARY_PATH", unset = NA)
  Sys.unsetenv("LD_LIBRARY_PATH")
  do.call(on.exit, list(substitute(
    if (!is.na(old)) Sys.setenv(LD_LIBRARY_PATH = old), list(old = old)),
    add = TRUE), envir = envir)
  invisible()
}


#' Julia Packages circuitscaper Needs
#'
#' Circuitscape.jl and Omniscape.jl, plus Tables.jl, which 'JuliaConnectoR'
#' needs (it would otherwise install it the first time Julia starts).
#' @noRd
julia_packages <- function() c("Circuitscape", "Omniscape", "Tables")


#' Install Julia Packages
#'
#' Adds (and optionally updates) Julia packages in a child Julia process
#' with a clean library path (see `run_julia_script()`).
#'
#' @param julia_bin Path to the Julia executable.
#' @param packages Character. Julia packages to add.
#' @param update Logical. Also update `packages` to their latest versions.
#' @param quiet Logical. Hide Julia's output unless something fails.
#' @return `TRUE` invisibly. Stops with Julia's output on failure.
#' @noRd
install_julia_packages <- function(julia_bin, packages, update = FALSE,
                                   quiet = TRUE) {
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
  check_julia_script(res, "installing ", paste(packages, collapse = ", "))
  invisible(TRUE)
}


#' Stop if a Julia Child Process Failed
#' @param res As from `run_julia_script()`.
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
