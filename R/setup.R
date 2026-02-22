#' Set Up Julia and Load Circuitscape/Omniscape
#'
#' Initialize the Julia session and load the Circuitscape and Omniscape Julia
#' packages. This is called automatically on first use of any `cs_*` or `os_*`
#' function. Call explicitly to control the Julia path or pre-warm the session.
#'
#' @param julia_home Character. Path to the Julia installation directory. If
#'   `NULL` (default), JuliaCall searches standard locations.
#' @param quiet Logical. Suppress Julia startup messages. Default `TRUE`.
#' @param ... Additional arguments passed to [JuliaCall::julia_setup()].
#'
#' @return Invisibly returns `TRUE` on success.
#'
#' @details
#' Following the pattern established by diffeqr, `cs_setup()` will:
#' * Install Julia automatically if missing (via `installJulia = TRUE`).
#' * Install the Circuitscape and Omniscape Julia packages if missing.
#' * Pass `...` through to [JuliaCall::julia_setup()] so users can set
#'   `JULIA_HOME`, `rebuild`, etc.
#'
#' Once Julia is initialized, it stays warm for the R session. Subsequent calls
#' to `cs_setup()` return immediately.
#'
#' @examples
#' \dontrun{
#' cs_setup()
#' cs_setup(julia_home = "/usr/local/julia/bin")
#' }
#'
#' @export
cs_setup <- function(julia_home = NULL, quiet = TRUE, ...) {
  if (.cs_env$julia_ready) {
    return(invisible(TRUE))
  }

  setup_args <- list(installJulia = TRUE, ...)
  if (!is.null(julia_home)) {
    setup_args$JULIA_HOME <- julia_home
  } else if (is.null(setup_args$JULIA_HOME)) {
    # Auto-detect system Julia to avoid JuliaCall defaulting to a stale
    # bundled installation (e.g. 1.9) when a newer system Julia exists
    sys_julia <- find_system_julia()
    if (!is.null(sys_julia)) {
      setup_args$JULIA_HOME <- sys_julia
    }
  }

  if (quiet) {
    suppressMessages(do.call(JuliaCall::julia_setup, setup_args))
  } else {
    do.call(JuliaCall::julia_setup, setup_args)
  }

  JuliaCall::julia_install_package_if_needed("Circuitscape")
  JuliaCall::julia_install_package_if_needed("Omniscape")

  JuliaCall::julia_library("Circuitscape")
  .cs_env$loaded_packages <- c(.cs_env$loaded_packages, "Circuitscape")

  JuliaCall::julia_library("Omniscape")
  .cs_env$loaded_packages <- c(.cs_env$loaded_packages, "Omniscape")

  # Apply compatibility patches for newer Julia versions
  patch_file <- system.file("julia", "patches.jl", package = "circuitscaper")
  if (nchar(patch_file) > 0 && file.exists(patch_file)) {
    JuliaCall::julia_source(patch_file)
  }

  .cs_env$julia_ready <- TRUE
  invisible(TRUE)
}


#' Install Julia and Required Packages
#'
#' One-time helper that installs Julia and the Circuitscape and Omniscape Julia
#' packages. Intended for first-time users.
#'
#' @param version Character. Julia version to install. Default `"latest"`.
#'
#' @return Invisibly returns `TRUE` on success.
#'
#' @examples
#' \dontrun{
#' cs_install_julia()
#' }
#'
#' @export
cs_install_julia <- function(version = "latest") {
  if (version == "latest") {
    JuliaCall::install_julia()
  } else {
    JuliaCall::install_julia(version = version)
  }

  JuliaCall::julia_setup(installJulia = FALSE)
  JuliaCall::julia_install_package("Circuitscape")
  JuliaCall::julia_install_package("Omniscape")

  message("Julia, Circuitscape, and Omniscape installed successfully.")
  invisible(TRUE)
}


#' Ensure Julia is Ready
#'
#' Internal helper that calls [cs_setup()] if Julia hasn't been initialized yet.
#'
#' @param ... Arguments passed to [cs_setup()].
#' @return `TRUE` invisibly.
#' @noRd
ensure_julia <- function(...) {
  if (!.cs_env$julia_ready) {
    cs_setup(...)
  }
  invisible(TRUE)
}


#' Find System Julia Installation
#'
#' Searches for a Julia binary on the system PATH or in common locations
#' (e.g., juliaup). Returns the directory containing the binary, or NULL.
#'
#' @return Character path to the Julia `bin/` directory, or `NULL`.
#' @noRd
find_system_julia <- function() {
  # Check PATH first
  julia_path <- Sys.which("julia")
  if (nchar(julia_path) > 0) {
    # Resolve symlinks/launchers to find the real binary
    real_path <- tryCatch(
      system2("julia", c("-e", '"println(Sys.BINDIR)"'), stdout = TRUE, stderr = FALSE),
      error = function(e) NULL
    )
    if (!is.null(real_path) && length(real_path) == 1 && nchar(real_path) > 0) {
      return(real_path)
    }
    # Fall back to the directory of the found binary
    return(dirname(julia_path))
  }
  NULL
}
