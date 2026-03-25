#' Set Up Julia and Load Circuitscape/Omniscape
#'
#' Initialize the Julia session and load the Circuitscape and Omniscape Julia
#' packages. This is called automatically on first use of any `cs_*` or `os_*`
#' function. Call explicitly to control the Julia path, number of threads, or
#' pre-warm the session.
#'
#' `cs_setup()` does **not** install Julia or Julia packages. If Julia is not
#' found or the required packages are missing, it throws an informative error
#' directing you to [cs_install_julia()].
#'
#' @param julia_home Character. Path to the Julia `bin/` directory. If
#'   `NULL` (default), the system PATH and common locations are searched.
#' @param threads Integer. Number of Julia threads to start. Default `1L`.
#'   Must be set before Julia initializes — once Julia is running, the thread
#'   count cannot be changed without restarting R. This setting controls
#'   parallelism for [os_run()] only; Circuitscape functions (`cs_*`) run
#'   single-threaded regardless of this value.
#' @param quiet Logical. Suppress Julia startup messages. Default `TRUE`.
#' @param ... Additional arguments passed to [JuliaCall::julia_setup()].
#'
#' @return Invisibly returns `TRUE` on success.
#'
#' @details
#' `cs_setup()` will:
#' * Verify that Julia is installed and accessible.
#' * Verify that the Circuitscape and Omniscape Julia packages are installed.
#' * Load both packages and warm up the JIT compiler.
#'
#' Once Julia is initialized, it stays warm for the R session. Subsequent calls
#' to `cs_setup()` return immediately.
#'
#' ## Threading
#' Julia's thread count is fixed at startup and cannot be changed mid-session.
#' Multi-threading is used by [os_run()] when `parallelize = TRUE`.
#' Circuitscape functions (`cs_pairwise`, `cs_one_to_all`, etc.) do not
#' benefit from multiple threads.
#'
#' ```
#' cs_setup(threads = 4)
#' os_run(resistance, radius = 50, parallelize = TRUE)
#' ```
#'
#' @references
#' Circuitscape: \url{https://docs.circuitscape.org/Circuitscape.jl/latest/}
#'
#' Omniscape: \url{https://docs.circuitscape.org/Omniscape.jl/latest/}
#'
#' @seealso [cs_install_julia()], [cs_pairwise()], [os_run()]
#'
#' @examples
#' \donttest{
#' cs_setup()
#' cs_setup(threads = 4)
#' cs_setup(julia_home = "/usr/local/julia/bin")
#' }
#'
#' @export
cs_setup <- function(julia_home = NULL, threads = 1L, quiet = TRUE, ...) {
  if (.cs_env$julia_ready) {
    return(invisible(TRUE))
  }

  # --- Check that Julia is available ---
  if (is.null(julia_home)) {
    julia_home <- find_system_julia()
  }
  if (is.null(julia_home)) {
    stop(
      "Julia not found. To fix this, run:\n",
      "  cs_install_julia()\n",
      "If Julia is already installed elsewhere, specify the path:\n",
      "  cs_setup(julia_home = \"/path/to/julia/bin\")",
      call. = FALSE
    )
  }

  # Set thread count before Julia initializes
  threads <- as.integer(threads)
  if (threads > 1L) {
    # Use "N,0" format: N default threads, 0 interactive threads.
    # Without this, JuliaCall runs on Julia's interactive thread whose ID
    # exceeds nthreads(), causing BoundsError in packages (like Omniscape)
    # that size thread-local arrays to nthreads().
    Sys.setenv(JULIA_NUM_THREADS = paste0(threads, ",0"))
  }
  .cs_env$julia_threads <- threads

  # Initialize Julia (do NOT auto-install)
  message("Initializing Julia (one-time per session)...")
  setup_args <- list(installJulia = FALSE, JULIA_HOME = julia_home, ...)
  if (quiet) {
    suppressMessages(do.call(JuliaCall::julia_setup, setup_args))
  } else {
    do.call(JuliaCall::julia_setup, setup_args)
  }

  # --- Check that required Julia packages are installed ---
  missing_pkgs <- character(0)
  if (identical(JuliaCall::julia_installed_package("Circuitscape"), "nothing")) {
    missing_pkgs <- c(missing_pkgs, "Circuitscape")
  }
  if (identical(JuliaCall::julia_installed_package("Omniscape"), "nothing")) {
    missing_pkgs <- c(missing_pkgs, "Omniscape")
  }
  if (length(missing_pkgs) > 0) {
    stop(
      "Required Julia package(s) not installed: ",
      paste(missing_pkgs, collapse = ", "), ".\n",
      "Run cs_install_julia() to install all required packages.",
      call. = FALSE
    )
  }

  # Load packages
  message("Loading Circuitscape and Omniscape...")
  JuliaCall::julia_library("Circuitscape")
  .cs_env$loaded_packages <- c(.cs_env$loaded_packages, "Circuitscape")

  JuliaCall::julia_library("Omniscape")
  .cs_env$loaded_packages <- c(.cs_env$loaded_packages, "Omniscape")

  # Apply compatibility patches for newer Julia versions
  patch_file <- system.file("julia", "patches.jl", package = "circuitscaper")
  if (nchar(patch_file) > 0 && file.exists(patch_file)) {
    JuliaCall::julia_source(patch_file)
  }

  # Warm up Julia's JIT compiler by running a tiny Circuitscape problem.
  # Without this, the first real cs_*() call pays a ~20 s compilation penalty.
  message("Warming up JIT compiler (this may take a moment)...")
  warmup_jl <- '
    let
      d = mktempdir()
      try
        # 3x3 resistance grid
        open(joinpath(d, "r.asc"), "w") do f
          println(f, "ncols         3")
          println(f, "nrows         3")
          println(f, "xllcorner     0")
          println(f, "yllcorner     0")
          println(f, "cellsize      1")
          println(f, "NODATA_value  -9999")
          for _ in 1:3; println(f, "1 1 1"); end
        end
        # focal nodes
        open(joinpath(d, "p.asc"), "w") do f
          println(f, "ncols         3")
          println(f, "nrows         3")
          println(f, "xllcorner     0")
          println(f, "yllcorner     0")
          println(f, "cellsize      1")
          println(f, "NODATA_value  -9999")
          println(f, "1 0 0")
          println(f, "0 0 0")
          println(f, "0 0 2")
        end
        # minimal INI
        ini = joinpath(d, "w.ini")
        open(ini, "w") do f
          println(f, "[Circuitscape mode]")
          println(f, "scenario = pairwise")
          println(f, "[Habitat raster]")
          println(f, "habitat_file = ", joinpath(d, "r.asc"))
          println(f, "[Options for pairwise and one-to-all and all-to-one modes]")
          println(f, "point_file = ", joinpath(d, "p.asc"))
          println(f, "use_included_pairs = false")
          println(f, "[Output options]")
          println(f, "write_cur_maps = false")
          println(f, "write_volt_maps = false")
          println(f, "write_cum_cur_map_only = false")
          println(f, "output_file = ", joinpath(d, "out"))
        end
        redirect_stdout(devnull) do
          redirect_stderr(devnull) do
            Circuitscape.compute(ini)
          end
        end
      finally
        rm(d; recursive = true, force = true)
      end
    end
  '
  tryCatch(
    JuliaCall::julia_eval(warmup_jl),
    error = function(e) {
      if (!quiet) warning("JIT warmup failed (non-fatal): ", conditionMessage(e))
    }
  )

  message("Ready.")
  .cs_env$julia_ready <- TRUE
  invisible(TRUE)
}


#' Install Julia and Required Packages
#'
#' Downloads and installs Julia, Circuitscape.jl, and Omniscape.jl. This is
#' the recommended first step after installing the circuitscaper R package.
#'
#' In interactive sessions, prompts for confirmation before downloading. In
#' non-interactive sessions (e.g., CI), proceeds without prompting.
#'
#' @param force Logical. If `TRUE`, reinstall Julia and packages even if they
#'   appear to be already present. Default `FALSE`.
#' @param version Character. Julia version to install. Default `"latest"`.
#'
#' @return Invisibly returns `TRUE` on success, `FALSE` if cancelled.
#'
#' @examples
#' \donttest{
#' cs_install_julia()
#' cs_install_julia(force = TRUE)
#' }
#'
#' @export
cs_install_julia <- function(force = FALSE, version = "latest") {
  julia_home <- find_system_julia()
  need_julia <- force || is.null(julia_home)

  # Prompt for confirmation in interactive sessions
  if (interactive()) {
    if (need_julia) {
      msg <- paste0(
        "circuitscaper requires Julia and two Julia packages.\n",
        "This will download and install:\n",
        "
 Julia (~500 MB)\n",
        "
 Circuitscape.jl and Omniscape.jl (~500 MB)\n",
        "\nProceed?"
      )
    } else {
      msg <- paste0(
        "Julia found at: ", julia_home, "\n",
        "This will install/update the required Julia packages:\n",
        "
 Circuitscape.jl and Omniscape.jl (~500 MB)\n",
        "\nProceed?"
      )
    }
    answer <- utils::askYesNo(msg, default = TRUE)
    if (!isTRUE(answer)) {
      message("Installation cancelled.")
      return(invisible(FALSE))
    }
  }

  # Step 1: Install Julia if needed
  if (need_julia) {
    message("Installing Julia...")
    if (version == "latest") {
      JuliaCall::install_julia()
    } else {
      JuliaCall::install_julia(version = version)
    }
  } else {
    message("Julia already installed at: ", julia_home)
  }

  # Step 2: Initialize Julia so we can install packages
  message("Initializing Julia...")
  julia_home <- find_system_julia()
  setup_args <- list(installJulia = FALSE)
  if (!is.null(julia_home)) {
    setup_args$JULIA_HOME <- julia_home
  }
  suppressMessages(do.call(JuliaCall::julia_setup, setup_args))

  # Step 3: Install Julia packages
  message("Installing Circuitscape.jl...")
  JuliaCall::julia_install_package("Circuitscape")

  message("Installing Omniscape.jl...")
  JuliaCall::julia_install_package("Omniscape")

  message("Installation complete. Julia and all required packages are ready.")

  # Step 4: Complete session setup (loads packages, JIT warmup, etc.)
  cs_setup(quiet = TRUE)

  invisible(TRUE)
}


#' Ensure Julia is Ready
#'
#' Internal helper that calls [cs_setup()] if Julia hasn't been initialized
#' yet. If Julia or required packages are not installed, an informative error
#' is thrown directing the user to [cs_install_julia()].
#'
#' @return `TRUE` invisibly.
#' @noRd
ensure_julia <- function() {
  if (!.cs_env$julia_ready) {
    cs_setup()
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
