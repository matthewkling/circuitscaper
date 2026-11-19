#' Set Up Julia
#'
#' Start the Julia session that circuitscaper's functions run in. This is
#' called automatically on first use of any `cs_*()`, `os_*()` or `dp_*()`
#' function. Call it explicitly to control the Julia path or the number of
#' threads, ideally at the start of your session.
#'
#' `cs_setup()` does **not** install Julia or Julia packages. If Julia is not
#' found, it throws an informative error directing you to
#' [cs_install_julia()].
#'
#' @param julia_home Character. Path to the Julia `bin/` directory. If
#'   `NULL` (default), Julia is looked for in: the `JULIA_HOME` option or
#'   environment variable, the `JULIA_BINDIR` environment variable, a Julia
#'   installed by [cs_install_julia()] (or by `JuliaCall::install_julia()`),
#'   the system PATH (including a login shell's PATH on macOS and Linux), and
#'   common Windows install locations.
#' @param threads Integer. Number of Julia threads. Default `1L`. If Julia
#'   is already running with fewer threads, it is restarted with `threads`
#'   threads (see Threading, below). This setting controls parallelism for
#'   [os_run()] and the dipole methods (`dp_*`); Circuitscape functions
#'   (`cs_*`) run single-threaded regardless of this value.
#' @param quiet Logical. Suppress Julia startup messages. Default `TRUE`.
#'
#' @return Invisibly returns `TRUE` on success.
#'
#' @details
#' `cs_setup()` verifies that Julia is installed and accessible, and starts
#' it with the requested threads. Julia runs in its own process, connected to
#' R by 'JuliaConnectoR'.
#'
#' The Circuitscape and Omniscape Julia packages are loaded later, the first
#' time a `cs_*()` or `os_*()` function runs: that call checks they are
#' installed, loads them and warms up Julia's compiler, which takes a few
#' seconds to a minute once per session. The dipole methods (`dp_*()`) need
#' neither package, so a session that only uses them skips that step.
#'
#' Once Julia is initialized, it stays warm for the R session. Subsequent calls
#' to `cs_setup()` return immediately. If the Julia process has stopped in
#' the meantime (for example, it crashed or ran out of memory, or was stopped
#' with `JuliaConnectoR::stopJulia()`), the next `cs_setup()` call, or the
#' next `cs_*()`, `os_*()` or `dp_*()` call, starts and sets up Julia again.
#'
#' ## Threading
#' Multi-threading is used by [os_run()] when `parallelize = TRUE`, and
#' always by the dipole methods (e.g., [dp_omni()]).
#' Circuitscape functions (`cs_pairwise`, `cs_one_to_all`, etc.) do not
#' benefit from multiple threads.
#'
#' ```
#' cs_setup(threads = 4)
#' os_run(resistance, radius = 50, parallelize = TRUE)
#' ```
#'
#' Julia's thread count is fixed when Julia starts, so if Julia is already
#' running with fewer threads, `cs_setup(threads = )` restarts it. After a
#' restart, Circuitscape and Omniscape are loaded and warmed up again on the
#' next `cs_*()` or `os_*()` call, and circuits from [dp_circuit()] are
#' rebuilt when next used. A restart also discards anything else in this R
#' session's Julia (e.g., objects created through 'JuliaConnectoR' by other
#' code). Asking for fewer threads than Julia has doesn't restart it.
#'
#' Julia is started with `JULIA_NUM_THREADS` set to `"N,0"`: N threads and no
#' interactive threads. Omniscape releases before 0.6.3 fail in parallel
#' when Julia has an interactive thread, so `cs_setup(threads = )` also
#' restarts a Julia that has one, and [os_run()] falls back to a serial run
#' with a warning if it finds one.
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
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
cs_setup <- function(julia_home = NULL, threads = 1L, quiet = TRUE) {
  threads <- as.integer(threads)
  if (.cs_env$julia_ready) {
    state <- julia_session_state()
    if (!identical(state, "ready")) {
      # The Julia set up earlier is gone (it crashed, or was stopped); set up
      # again. A broken connection must be closed before Julia can restart.
      forget_julia(stop = identical(state, "broken"))
    } else if (julia_needs_restart(threads, .cs_env$julia_threads,
                                   .cs_env$julia_interactive)) {
      message("Restarting Julia with ", threads, " threads...")
      forget_julia(stop = TRUE)
    } else {
      return(invisible(TRUE))
    }
  }
  init_julia(julia_home = julia_home, threads = threads, quiet = quiet)
}


#' Start Julia
#'
#' The body of [cs_setup()] when Julia isn't set up yet. Circuitscape and
#' Omniscape are loaded separately, by `load_circuitscape()`.
#' @param julia_home,threads,quiet As for [cs_setup()].
#' @noRd
init_julia <- function(julia_home = NULL, threads = 1L, quiet = TRUE) {
  # Request threads before Julia starts. If Julia is already running (e.g.,
  # started by another package that uses JuliaConnectoR) with too few
  # threads, it is restarted below.
  if (threads > 1L) {
    # Use "N,0" format: N default threads, 0 interactive threads. Since
    # Julia 1.12 the interactive pool takes thread id 1, so with an
    # interactive thread, worker thread ids run past nthreads(). Omniscape
    # releases before 0.6.3 index per-thread arrays by threadid() and fail
    # with a BoundsError in that case.
    Sys.setenv(JULIA_NUM_THREADS = paste0(threads, ",0"))
  }

  # Find Julia (do NOT auto-install). find_julia_bin() searches the JULIA_HOME
  # option and environment variable, JULIA_BINDIR, a Julia installed by
  # cs_install_julia(), JuliaCall's install record, the PATH, a login shell's
  # PATH (for GUI sessions on macOS), and common Windows install locations.
  # When restarting, reuse the Julia found before. The Julia found is passed
  # to JuliaConnectoR explicitly, so the Julia whose version is checked below
  # is the one that starts.
  if (!is.null(julia_home)) {
    julia_bin <- file.path(julia_home, julia_exe())
    if (!file.exists(julia_bin)) {
      stop(julia_not_found_message(julia_home), call. = FALSE)
    }
  } else if (!is.null(.cs_env$julia_bin) && file.exists(.cs_env$julia_bin)) {
    julia_bin <- .cs_env$julia_bin
  } else {
    julia_bin <- find_julia_bin()
    if (is.null(julia_bin)) {
      stop(julia_not_found_message(), call. = FALSE)
    }
  }

  # Refuse Julia versions the Julia packages no longer support. Otherwise
  # Julia's package manager falls back to old releases that fail in obscure
  # ways.
  check_julia_version(julia_bin)

  message("Initializing Julia (one-time per session)...")
  start_julia(julia_bin, quiet = quiet, julia_home = julia_home)
  check_running_julia_version()

  # Julia may already have been running with a thread layout that can't
  # honor the request; if so, restart it (once) with JULIA_NUM_THREADS set.
  nthreads <- julia_nthreads()
  ninteractive <- julia_ninteractive()
  if (julia_needs_restart(threads, nthreads, ninteractive)) {
    message("Restarting Julia with ", threads, " threads (it was already ",
            "running with ", nthreads, ")...")
    jl_stop()
    start_julia(julia_bin, quiet = quiet, julia_home = julia_home)
    check_running_julia_version()
    nthreads <- julia_nthreads()
    ninteractive <- julia_ninteractive()
    if (julia_needs_restart(threads, nthreads, ninteractive)) {
      warning(thread_mismatch_message(nthreads, threads), call. = FALSE)
    }
  }
  .cs_env$julia_bin <- julia_bin
  .cs_env$julia_threads <- nthreads
  .cs_env$julia_interactive <- if (is.na(ninteractive)) 0L else ninteractive
  .cs_env$loaded_packages <- character(0)

  mark_julia_ready()
  .cs_env$julia_ready <- TRUE
  invisible(TRUE)
}


#' Load Circuitscape and Omniscape Into the Running Julia
#'
#' Checks that both packages are installed, loads them, applies the
#' compatibility patches and warms up Julia's compiler with a tiny
#' Circuitscape run. Returns at once if they are already loaded in this
#' Julia. Called by `ensure_julia()` for the `cs_*()` and `os_*()` functions
#' (and by [cs_install_julia()]); the dipole methods don't need it.
#'
#' @param quiet Logical. Hide a failed warm-up's warning.
#' @return `TRUE` invisibly.
#' @noRd
load_circuitscape <- function(quiet = TRUE) {
  if (all(c("Circuitscape", "Omniscape") %in% .cs_env$loaded_packages)) {
    return(invisible(TRUE))
  }

  # --- Check that required Julia packages are installed ---
  missing_pkgs <- character(0)
  for (pkg in c("Circuitscape", "Omniscape")) {
    if (!jl_package_installed(pkg)) missing_pkgs <- c(missing_pkgs, pkg)
  }
  if (length(missing_pkgs) > 0) {
    stop(
      "Julia package(s) needed by the cs_*() and os_*() functions are not ",
      "installed: ", paste(missing_pkgs, collapse = ", "), ".\n",
      "Run cs_install_julia() to install them.",
      call. = FALSE
    )
  }

  # Load packages
  message("Loading Circuitscape and Omniscape (one-time per session)...")
  jl_eval("using Circuitscape")
  jl_eval("using Omniscape")

  # Apply compatibility patches for newer Julia versions
  patch_file <- system.file("julia", "patches.jl", package = "circuitscaper")
  if (nchar(patch_file) > 0 && file.exists(patch_file)) {
    jl_eval(paste0("include(", jl_string(patch_file), "); nothing"))
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
    jl_eval(paste0(warmup_jl, "; nothing")),
    error = function(e) {
      if (!quiet) warning("JIT warmup failed (non-fatal): ", conditionMessage(e))
    }
  )

  # Recorded only once everything above succeeded, so a failed load is
  # retried on the next call
  .cs_env$loaded_packages <- union(.cs_env$loaded_packages,
                                   c("Circuitscape", "Omniscape"))
  message("Ready.")
  invisible(TRUE)
}


#' Install Julia and Required Packages
#'
#' Downloads and installs Julia, Circuitscape.jl, and Omniscape.jl. This is
#' the recommended first step after installing the circuitscaper R package.
#' If you only use the dipole methods (`dp_*()`), `circuitscape = FALSE`
#' installs Julia alone, which is faster and smaller.
#'
#' In interactive sessions, prompts for confirmation before downloading. In
#' non-interactive sessions (e.g., CI), proceeds without prompting.
#'
#' If no suitable Julia is found (see [cs_setup()] for where it looks), or if
#' `force = TRUE`, the official Julia release for your platform is downloaded
#' from julialang.org, checked against its published size and checksum, and
#' unpacked into circuitscaper's user data directory
#' (`tools::R_user_dir("circuitscaper", "data")`). That Julia is then used by
#' [cs_setup()] in later sessions. Julia installed by other means (e.g.,
#' juliaup or the official installers) works too; in that case
#' `cs_install_julia()` just adds the Julia packages.
#'
#' The Julia packages are installed into Julia's default package depot
#' (usually `~/.julia`), as with any Julia installation.
#'
#' @param force Logical. If `TRUE`, download and install Julia even if a
#'   Julia installation is already present, and reinstall the Julia packages.
#'   Use this to replace a Julia installation that is too old. Default
#'   `FALSE`.
#' @param version Character. Julia version to install, e.g. `"1.12.1"`.
#'   Default `"latest"`, the latest stable release. Must be at least 1.10.
#' @param circuitscape Logical. Install the Circuitscape and Omniscape Julia
#'   packages, which the `cs_*()` and `os_*()` functions need. Default
#'   `TRUE`. If `FALSE`, only Julia (and Tables.jl, which 'JuliaConnectoR'
#'   uses) is installed: enough for the dipole methods (`dp_*()`). Run
#'   `cs_install_julia()` again later to add the packages.
#'
#' @return Invisibly returns `TRUE` on success, `FALSE` if cancelled.
#'
#' @examples
#' \dontrun{
#' cs_install_julia()
#'
#' # Only the dipole methods
#' cs_install_julia(circuitscape = FALSE)
#' }
#'
#' @export
cs_install_julia <- function(force = FALSE, version = "latest", circuitscape = TRUE) {
  circuitscape <- isTRUE(circuitscape)
  packages <- julia_packages(circuitscape)
  package_names <- if (circuitscape) "Circuitscape.jl and Omniscape.jl" else "Tables.jl"
  julia_bin <- find_julia_bin()
  need_julia <- force || is.null(julia_bin)

  # An existing Julia that is too old won't work; say how to replace it
  # rather than installing packages into it.
  if (!need_julia) {
    v <- julia_version(julia_bin)
    if (!is.null(v) && v < min_julia_version()) {
      stop(
        "Julia ", v, " (at ", julia_bin, ") is too old; circuitscaper ",
        "requires Julia >= ", min_julia_version(), ".\n",
        "To install a current Julia, run:\n",
        "  cs_install_julia(force = TRUE)\n",
        "or update your Julia installation (e.g., with juliaup).",
        call. = FALSE
      )
    }
  }

  # Check the requested version before downloading anything
  if (need_julia && !identical(version, "latest")) {
    v <- tryCatch(package_version(version), error = function(e) NULL)
    if (is.null(v)) {
      stop("`version` must be \"latest\" or a version number such as ",
           "\"1.12.1\".", call. = FALSE)
    }
    if (v < min_julia_version()) {
      stop("circuitscaper requires Julia >= ", min_julia_version(),
           "; got version = \"", version, "\".", call. = FALSE)
    }
  }

  # Prompt for confirmation in interactive sessions
  if (interactive()) {
    if (need_julia) {
      msg <- paste0(
        if (circuitscape) "circuitscaper requires Julia and two Julia packages.\n"
        else "The dipole methods require Julia.\n",
        "This will download and install:\n",
        "  - Julia ", if (identical(version, "latest")) "(latest release)"
        else version, ", into ", julia_install_root(), "\n",
        "  - ", package_names, ", into Julia's package depot\n",
        if (circuitscape) "Together these take about 1-2 GB of disk space.\n",
        "\nProceed?"
      )
    } else {
      msg <- paste0(
        "Julia found at: ", julia_bin, "\n",
        "This will install or update the required Julia packages\n",
        "(", package_names, ").\n",
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
    julia_home <- install_julia_binary(version)
  } else {
    message("Using Julia at: ", julia_bin)
    julia_home <- dirname(julia_bin)
  }

  # Step 2: Install the Julia packages, in a child Julia process rather than
  # in a Julia session inside R (see install_julia_dependencies())
  julia_bin <- file.path(julia_home, julia_exe())
  check_julia_version(julia_bin)
  message("Installing ", package_names,
          if (circuitscape) " (this can take several minutes)", "...")
  install_julia_packages(julia_bin, packages, update = force, quiet = FALSE)

  message("Installation complete. Julia and all required packages are ready.")

  # Step 3: Complete session setup (starts Julia; with the Circuitscape
  # packages, also loads them and warms up the compiler)
  cs_setup(julia_home = julia_home, quiet = TRUE)
  if (circuitscape) load_circuitscape(quiet = TRUE)

  invisible(TRUE)
}


#' Ensure Julia is Ready
#'
#' Internal helper that calls [cs_setup()], which sets up Julia if it isn't
#' set up yet (or is no longer running), and then loads Circuitscape and
#' Omniscape if they aren't loaded yet. If Julia or required packages are
#' not installed, an informative error is thrown directing the user to
#' [cs_install_julia()].
#'
#' @param circuitscape Logical. Also load Circuitscape and Omniscape, as the
#'   `cs_*()` and `os_*()` functions need. The dipole methods pass `FALSE`.
#' @return `TRUE` invisibly.
#' @noRd
ensure_julia <- function(circuitscape = TRUE) {
  # When Julia is set up, cs_setup() only checks that it's still running.
  cs_setup()
  if (circuitscape) load_circuitscape()
  invisible(TRUE)
}


#' Check if Julia and Required Packages Are Available
#'
#' Tests whether Julia is installed and the Circuitscape and Omniscape Julia packages
#' can be loaded. This is a lightweight check that does not initialize a full Julia
#' session. It is used internally by example code and can be called by users
#' to verify their setup before running analyses.
#'
#' @param circuitscape Logical. Also check that the Circuitscape and
#'   Omniscape Julia packages load, as the `cs_*()` and `os_*()` functions
#'   need. Default `TRUE`. Use `FALSE` to check for what the dipole methods
#'   (`dp_*()`) need: a Julia that runs and is recent enough.
#'
#' @return `TRUE` if Julia is found (in the places [cs_setup()] searches) and
#'   runs, is at least the minimum version, and (with `circuitscape = TRUE`)
#'   loads the 'Circuitscape' and 'Omniscape' Julia packages; `FALSE`
#'   otherwise.
#'
#' @examples
#' cs_julia_available()
#' cs_julia_available(circuitscape = FALSE)
#'
#' @export
cs_julia_available <- function(circuitscape = TRUE) {
      julia_bin <- find_julia_bin()
      if (is.null(julia_bin)) return(FALSE)
      v <- julia_version(julia_bin)
      if (is.null(v) || v < min_julia_version()) return(FALSE)
      # `julia --version` succeeds even when Julia can't start (e.g. a
      # missing system image), so start it, as cs_setup() would: from its own
      # binary directory
      bindir <- julia_bindir(julia_bin)
      if (is.null(bindir)) return(FALSE)
      if (!isTRUE(circuitscape)) return(TRUE)
      # generous: the first load after an install precompiles
      julia_runs(file.path(bindir, julia_exe()),
                 "using Circuitscape, Omniscape; println(true)", timeout = 600)
}


#' Run Julia Code in a Fresh Julia Process
#'
#' @param julia_bin Path to the Julia executable.
#' @param code Julia code that prints `true` on success.
#' @param timeout Seconds to wait.
#' @return `TRUE` if Julia ran and printed `true`, `FALSE` otherwise.
#' @noRd
julia_runs <- function(julia_bin, code, timeout) {
      local_clean_library_path()
      local_unset_bindir()
      tryCatch({
            out <- suppressWarnings(system2(
                  julia_bin,
                  c("--startup-file=no", "-e", shQuote(code, type = "cmd")),
                  stdout = TRUE, stderr = FALSE, timeout = timeout
            ))
            any(trimws(out) == "true")
      }, error = function(e) FALSE)
}


#' Find a Julia Binary Without Starting Julia
#'
#' Looks for the Julia executable, in order: the `JULIA_HOME` option, the
#' `JULIA_HOME` environment variable, the `JULIA_BINDIR` environment variable
#' (which 'JuliaConnectoR' uses), a Julia installed by
#' [cs_install_julia()], the install record that `JuliaCall::install_julia()`
#' writes to `<depot>/prefs/JuliaCall`, the PATH, a login shell's PATH on
#' Unix-alikes (GUI sessions on macOS often lack the shell PATH), and
#' `%LOCALAPPDATA%/Julia*` on Windows. Apart from circuitscaper's own install
#' (which comes before JuliaCall's record, so that `cs_install_julia(force =
#' TRUE)` replaces a stale Julia that JuliaCall installed), this mirrors
#' JuliaCall's internal locator.
#'
#' It does not start Julia, so it is cheap enough for `.onAttach()`.
#' [cs_setup()] passes the Julia it finds to 'JuliaConnectoR' explicitly, so
#' the two can't disagree.
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

  # 1-2. JULIA_HOME option, then environment variables
  bin <- in_dir(getOption("JULIA_HOME"))
  if (!is.null(bin)) return(bin)
  bin <- in_dir(Sys.getenv("JULIA_HOME"))
  if (!is.null(bin)) return(bin)
  bin <- in_dir(Sys.getenv("JULIA_BINDIR"))
  if (!is.null(bin)) return(bin)

  # 3. Julia installed by cs_install_julia()
  bin <- installed_julia_bin()
  if (!is.null(bin)) return(bin)

  # 4. Install record written by JuliaCall::install_julia()
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

  # 5. PATH
  bin <- Sys.which("julia")
  if (nzchar(bin)) return(unname(bin))

  # 6. Login shell PATH (Unix-alikes) or common install location (Windows)
  if (!windows && login_shell) {
    bin <- tryCatch(
      # timeout: a login shell runs the user's profile, which could be slow
      # or wait for input; this runs on package attach.
      suppressWarnings(system2("bash", c("-l", "-c", shQuote("command -v julia")),
                               stdout = TRUE, stderr = FALSE, timeout = 10)),
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
