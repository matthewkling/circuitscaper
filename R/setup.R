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
#'   `NULL` (default), Julia is located the same way as
#'   [JuliaCall::julia_setup()]: the `JULIA_HOME` option or environment
#'   variable, a Julia installed by [cs_install_julia()] or
#'   [JuliaCall::install_julia()], the system PATH (including a login
#'   shell's PATH on macOS and Linux), and common Windows install locations.
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
#' McRae, B.H. (2006). Isolation by resistance. \emph{Evolution}, 60(8),
#' 1551--1561. \doi{10.1111/j.0014-3820.2006.tb00500.x}
#'
#' Landau, V.A., Shah, V.B., Anantharaman, R. & Hall, K.R. (2021).
#' Omniscape.jl: Software to compute omnidirectional landscape connectivity.
#' \emph{Journal of Open Source Software}, 6(57), 2829.
#' \doi{10.21105/joss.02829}
#'
#' Circuitscape.jl: \url{https://docs.circuitscape.org/Circuitscape.jl/latest/}
#'
#' Omniscape.jl: \url{https://docs.circuitscape.org/Omniscape.jl/latest/}
#'
#' @seealso [cs_install_julia()], [cs_pairwise()], [os_run()]
#'
#' @examplesIf circuitscaper::cs_julia_available()
#' cs_setup()
#' cs_setup(threads = 4)
#' cs_setup(julia_home = "/usr/local/julia/bin")
#'
#' @export
cs_setup <- function(julia_home = NULL, threads = 1L, quiet = TRUE, ...) {
  threads <- as.integer(threads)
  if (.cs_env$julia_ready) {
    if (threads > .cs_env$julia_threads) {
      warning(thread_mismatch_message(.cs_env$julia_threads, threads),
              call. = FALSE)
    }
    return(invisible(TRUE))
  }

  # Set thread count before Julia initializes. This only takes effect if
  # Julia is not already running in this R session (e.g., started by
  # JuliaCall::julia_setup() directly); the actual count is checked below.
  if (threads > 1L) {
    # Use "N,0" format: N default threads, 0 interactive threads. Since
    # Julia 1.12 the interactive pool takes thread id 1, so with an
    # interactive thread, worker thread ids run past nthreads(). Omniscape
    # releases before 0.6.3 index per-thread arrays by threadid() and fail
    # with a BoundsError in that case.
    Sys.setenv(JULIA_NUM_THREADS = paste0(threads, ",0"))
  }

  # Initialize Julia (do NOT auto-install). Locating Julia is left to
  # JuliaCall::julia_setup(), which checks the JULIA_HOME option and
  # environment variable, the install record written by
  # JuliaCall::install_julia() (and so by cs_install_julia()), the PATH, a
  # login shell's PATH (for GUI sessions on macOS), and common Windows
  # install locations. It signals "Julia is not found." if all of these fail,
  # but only after printing shell warnings, so first rule out the clear-cut
  # cases quietly. find_julia_bin() searches the same places without
  # starting Julia.
  if (is.null(julia_home) && is.null(find_julia_bin())) {
    stop(julia_not_found_message(), call. = FALSE)
  }
  if (!is.null(julia_home) && !file.exists(file.path(julia_home, julia_exe()))) {
    stop(julia_not_found_message(julia_home), call. = FALSE)
  }
  message("Initializing Julia (one-time per session)...")
  setup_args <- list(installJulia = FALSE, ...)
  if (!is.null(julia_home)) {
    setup_args$JULIA_HOME <- julia_home
  }
  tryCatch(
    if (quiet) {
      suppressMessages(do.call(JuliaCall::julia_setup, setup_args))
    } else {
      do.call(JuliaCall::julia_setup, setup_args)
    },
    error = function(e) {
      if (grepl("Julia is not found", conditionMessage(e), fixed = TRUE)) {
        stop(julia_not_found_message(julia_home), call. = FALSE)
      }
      stop(e)
    }
  )

  # Record the thread count Julia actually has, which can differ from the
  # request if Julia was started before cs_setup() ran.
  .cs_env$julia_threads <- julia_nthreads()
  if (threads > .cs_env$julia_threads) {
    warning(thread_mismatch_message(.cs_env$julia_threads, threads),
            call. = FALSE)
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
#' \dontrun{
#' cs_install_julia()
#' }
#'
#' @export
cs_install_julia <- function(force = FALSE, version = "latest") {
  julia_bin <- find_julia_bin()
  need_julia <- force || is.null(julia_bin)

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
        "Julia found at: ", julia_bin, "\n",
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
    message("Julia already installed at: ", julia_bin)
  }

  # Step 2: Initialize Julia so we can install packages. JuliaCall locates
  # Julia itself, including one install_julia() just put outside the PATH.
  message("Initializing Julia...")
  suppressMessages(JuliaCall::julia_setup(installJulia = FALSE))

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


#' Check if Julia and Required Packages Are Available
#'
#' Tests whether Julia is installed and the Circuitscape and Omniscape Julia packages
#' can be loaded. This is a lightweight check that does not initialize a full Julia
#' session. It is used internally by example code and can be called by users
#' to verify their setup before running analyses.
#'
#' @return `TRUE` if Julia is found (in the places [cs_setup()] searches) and
#'   the 'Circuitscape' and 'Omniscape' Julia packages load successfully,
#'   `FALSE` otherwise.
#'
#' @examples
#' cs_julia_available()
#'
#' @export
cs_julia_available <- function() {
      julia_bin <- find_julia_bin()
      if (is.null(julia_bin)) return(FALSE)
      tryCatch({
            out <- system2(
                  julia_bin,
                  c("--startup-file=no", "-e", '"using Circuitscape, Omniscape; println(true)"'),
                  stdout = TRUE, stderr = FALSE
            )
            any(trimws(out) == "true")
      }, error = function(e) FALSE)
}


#' Find a Julia Binary Without Starting Julia
#'
#' Looks for the Julia executable in the same places, and in the same order,
#' as JuliaCall's internal locator (which `JuliaCall::julia_setup()` uses but
#' JuliaCall does not export): the `JULIA_HOME` option, the `JULIA_HOME`
#' environment variable, the install record that `JuliaCall::install_julia()`
#' writes to `<depot>/prefs/JuliaCall`, the PATH, a login shell's PATH on
#' Unix-alikes (GUI sessions on macOS often lack the shell PATH), and
#' `%LOCALAPPDATA%/Julia*` on Windows.
#'
#' Unlike JuliaCall's locator, this does not run Julia, so it is cheap enough
#' for `.onAttach()` and for deciding whether [cs_install_julia()] needs to
#' download Julia. [cs_setup()] uses it only to fail fast with a clean message
#' when no Julia exists; the actual locating is left to
#' `JuliaCall::julia_setup()`.
#'
#' @param login_shell Logical. Also ask a login shell (`bash -l`) on
#'   Unix-alikes. Default `TRUE`.
#' @return Character path to the Julia executable, or `NULL`.
#' @noRd
find_julia_bin <- function(login_shell = TRUE) {
  windows <- .Platform$OS.type == "windows"
  exe <- julia_exe()
  in_dir <- function(dir) {
    if (is.null(dir) || !nzchar(dir)) return(NULL)
    bin <- file.path(dir, exe)
    if (file.exists(bin)) normalizePath(bin, mustWork = FALSE) else NULL
  }

  # 1-2. JULIA_HOME option, then environment variable
  bin <- in_dir(getOption("JULIA_HOME"))
  if (!is.null(bin)) return(bin)
  bin <- in_dir(Sys.getenv("JULIA_HOME"))
  if (!is.null(bin)) return(bin)

  # 3. Install record written by JuliaCall::install_julia()
  depot <- Sys.getenv("JULIA_DEPOT_PATH")
  if (nzchar(depot)) {
    depot <- strsplit(depot, .Platform$path.sep, fixed = TRUE)[[1]][1]
  } else {
    home <- Sys.getenv(if (windows) "USERPROFILE" else "HOME")
    depot <- file.path(home, ".julia")
  }
  prefs <- file.path(depot, "prefs", "JuliaCall")
  if (file.exists(prefs)) {
    recorded <- trimws(readLines(prefs, n = 1L, warn = FALSE))
    bin <- in_dir(if (length(recorded)) recorded else NULL)
    if (!is.null(bin)) return(bin)
  }

  # 4. PATH
  bin <- Sys.which("julia")
  if (nzchar(bin)) return(unname(bin))

  # 5. Login shell PATH (Unix-alikes) or common install location (Windows)
  if (!windows && login_shell) {
    bin <- tryCatch(
      suppressWarnings(system2("bash", c("-l", "-c", shQuote("command -v julia")),
                               stdout = TRUE, stderr = FALSE)),
      error = function(e) character(0)
    )
    bin <- trimws(bin[nzchar(trimws(bin))])
    if (length(bin) && file.exists(bin[length(bin)])) return(bin[length(bin)])
  }
  if (windows) {
    appdata <- Sys.getenv("LOCALAPPDATA")
    if (nzchar(appdata) && dir.exists(appdata)) {
      dirs <- sort(list.dirs(appdata, recursive = FALSE, full.names = TRUE))
      dirs <- dirs[startsWith(basename(dirs), "Julia")]
      for (d in rev(dirs)) {
        bin <- in_dir(file.path(d, "bin"))
        if (!is.null(bin)) return(bin)
      }
    }
  }

  NULL
}


#' Name of the Julia Executable on This Platform
#' @noRd
julia_exe <- function() {
  if (.Platform$OS.type == "windows") "julia.exe" else "julia"
}


#' Message for When Julia Cannot Be Found
#'
#' @param julia_home The `julia_home` the user passed to [cs_setup()], or
#'   `NULL`.
#' @return Character string.
#' @noRd
julia_not_found_message <- function(julia_home = NULL) {
  if (!is.null(julia_home)) {
    return(paste0(
      "Julia not found at julia_home = \"", julia_home, "\".\n",
      "This should be the directory that contains the julia executable ",
      "(usually ending in bin/)."
    ))
  }
  paste0(
    "Julia not found. To fix this, run:\n",
    "  cs_install_julia()\n",
    "If Julia is already installed elsewhere, specify the path:\n",
    "  cs_setup(julia_home = \"/path/to/julia/bin\")"
  )
}
