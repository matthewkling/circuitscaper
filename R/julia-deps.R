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


#' Julia's Real bin/ Directory
#'
#' `julia_bin` may be a launcher (e.g., juliaup's) rather than the Julia
#' executable itself. If the directory has Julia's usual layout (a sibling
#' `lib/julia`), use it; otherwise ask Julia.
#'
#' @param julia_bin Path to a Julia executable or launcher.
#' @return Character path, or `NULL` if it can't be determined.
#' @noRd
julia_real_bindir <- function(julia_bin) {
  bindir <- dirname(julia_bin)
  if (dir.exists(file.path(bindir, "..", "lib", "julia"))) {
    return(normalizePath(bindir, mustWork = FALSE))
  }
  script <- tempfile(fileext = ".jl")
  on.exit(unlink(script), add = TRUE)
  writeLines("print(Sys.BINDIR)", script)
  res <- run_julia_script(julia_bin, script, quiet = TRUE)
  out <- res$output[nzchar(res$output)]
  if (!identical(res$status, 0L) || length(out) == 0) return(NULL)
  out[length(out)]
}


#' Load Julia's Own libunwind Into R, on Linux
#'
#' R starts with its library directories on `LD_LIBRARY_PATH` (including,
#' on Ubuntu, `/usr/lib/x86_64-linux-gnu`), so when JuliaCall starts Julia
#' inside R, Julia picks up the system libunwind instead of the one it
#' bundles. Ubuntu's libunwind 1.6.2 crashes Julia (R segfaults as Julia
#' starts; see JuliaInterop/JuliaCall#238). Loading Julia's libunwind first
#' means it is already present, by name, when Julia needs it. The
#' development version of JuliaCall does the same; the CRAN release doesn't.
#'
#' @param julia_bin Path to the Julia executable or launcher.
#' @return Path to the libunwind loaded, invisibly, or `NULL` if not on
#'   Linux or not found.
#' @noRd
preload_julia_libunwind <- function(julia_bin) {
  if (Sys.info()[["sysname"]] != "Linux") return(invisible(NULL))
  bindir <- julia_real_bindir(julia_bin)
  if (is.null(bindir)) return(invisible(NULL))
  libs <- sort(Sys.glob(file.path(bindir, "..", "lib", "julia",
                                  "libunwind.so*")))
  if (length(libs) == 0) return(invisible(NULL))
  lib <- normalizePath(libs[1], mustWork = FALSE)
  if (!identical(.cs_env$libunwind, lib)) {
    ok <- tryCatch({
      load_shared_library(lib)
      TRUE
    }, error = function(e) {
      warning("Could not preload Julia's libunwind (", lib, "): ",
              conditionMessage(e), call. = FALSE)
      FALSE
    })
    if (ok) .cs_env$libunwind <- lib
  }
  invisible(lib)
}


#' dyn.load() Wrapper, Separate So Tests Can Replace It
#' @noRd
load_shared_library <- function(path) {
  dyn.load(path, local = FALSE, now = TRUE)
}


#' Evaluate an Expression With LD_PRELOAD Set, on Linux
#'
#' For the Julia child processes JuliaCall itself launches while it starts
#' Julia (e.g., to find Julia's version and library), which inherit R's
#' library path.
#'
#' @param lib Library to preload, or `NULL` to just evaluate `expr`.
#' @param expr Expression to evaluate.
#' @noRd
with_ld_preload <- function(lib, expr) {
  if (is.null(lib)) return(expr)
  old <- Sys.getenv("LD_PRELOAD", unset = NA)
  Sys.setenv(LD_PRELOAD = paste(c(lib, if (!is.na(old) && nzchar(old)) old),
                                collapse = " "))
  on.exit(if (is.na(old)) Sys.unsetenv("LD_PRELOAD") else
    Sys.setenv(LD_PRELOAD = old), add = TRUE)
  expr
}
