#' Number of Julia Threads in the Running Session
#'
#' @return Integer. The size of Julia's default thread pool.
#' @noRd
julia_nthreads <- function() {
  as.integer(jl_eval("Threads.nthreads()"))
}


#' Number of Interactive Julia Threads in the Running Session
#' @return Integer, or `NA` if unavailable.
#' @noRd
julia_ninteractive <- function() {
  tryCatch(
    as.integer(jl_eval("Threads.nthreads(:interactive)")),
    error = function(e) NA_integer_
  )
}


#' Does Julia Need a Restart to Honor a Thread Request?
#'
#' Julia's thread layout is fixed when Julia starts, so [cs_setup()]
#' restarts Julia when the running one can't give `threads = requested`:
#' it has fewer threads, or it has an interactive thread (see
#' `omniscape_handles_interactive_threads()`). A request for one thread
#' never restarts Julia.
#'
#' @param requested Requested thread count.
#' @param nthreads,ninteractive As from `julia_nthreads()` and
#'   `julia_ninteractive()`.
#' @return Logical.
#' @noRd
julia_needs_restart <- function(requested, nthreads, ninteractive) {
  requested > 1L &&
    (requested > nthreads || isTRUE(ninteractive > 0L))
}


#' Thread Layout of the Running Julia Session
#'
#' Note that `Threads.maxthreadid()` is not a useful signal here: it also
#' counts garbage-collector threads (by default one fewer than the default
#' pool), so it exceeds `nthreads()` in any multithreaded session. GC threads
#' never run tasks, so only the interactive pool can push worker thread ids
#' past `nthreads()`.
#'
#' @return List with `nthreads` (default pool size), `ninteractive`
#'   (interactive pool size), and `omniscape_version` (character, or `NA` if
#'   unavailable).
#' @noRd
julia_thread_info <- function() {
  nthreads <- julia_nthreads()
  ninteractive <- julia_ninteractive()
  omniscape_version <- tryCatch(
    as.character(jl_eval("string(pkgversion(Omniscape))")),
    error = function(e) NA_character_
  )
  list(nthreads = nthreads, ninteractive = ninteractive,
       omniscape_version = omniscape_version)
}


#' Does This Omniscape Version Run in Parallel With Interactive Threads?
#'
#' Omniscape releases before 0.6.3 index per-thread accumulators by
#' `threadid()`, sized to `nthreads()`. Since Julia 1.12 the interactive
#' thread pool takes id 1, so when Julia has an interactive thread the
#' worker ids run past `nthreads()` and parallel runs fail with a
#' BoundsError. Omniscape 0.6.3 passes each task its slice explicitly.
#'
#' @param version Character Omniscape version, possibly with a prerelease or
#'   build suffix (e.g. "0.6.3-DEV"), or `NA`.
#' @return Logical.
#' @noRd
omniscape_handles_interactive_threads <- function(version) {
  if (length(version) != 1 || is.na(version)) return(FALSE)
  core <- sub("[-+].*$", "", version)
  v <- tryCatch(package_version(core), error = function(e) NULL)
  !is.null(v) && v >= "0.6.3"
}


#' How to Get a Multithreaded Julia Session
#' @param n Requested thread count.
#' @noRd
thread_fix_hint <- function(n) {
  n <- max(as.integer(n), 2L)
  paste0(
    "To run in parallel, call cs_setup(threads = ", n, "), which restarts ",
    "Julia with ", n, " threads."
  )
}


#' Warning Text for a Thread Request Julia Didn't Honor
#'
#' For when Julia still has the wrong thread layout after [cs_setup()]
#' restarted it with `JULIA_NUM_THREADS` set, i.e. something else sets
#' Julia's thread count.
#'
#' @param actual Threads Julia is running with.
#' @param requested Threads requested.
#' @noRd
thread_mismatch_message <- function(actual, requested) {
  paste0(
    "Julia started with ", actual, " thread(s) rather than the ", requested,
    " requested with threads = ", requested, " (JULIA_NUM_THREADS = \"",
    requested, ",0\"). Something else is setting Julia's thread count, ",
    "such as a --threads option in the JULIACONNECTOR_JULIAOPTS ",
    "environment variable."
  )
}


#' Decide Whether an Omniscape Run Can Use Julia's Threads
#'
#' Pure function of the session's thread layout, so it can be tested without
#' Julia.
#'
#' @param nthreads,ninteractive,omniscape_version As from
#'   `julia_thread_info()`. An `NA` `ninteractive` (unknown) does not block a
#'   parallel run.
#' @param requested The `julia_threads` the user asked for.
#' @return List with `parallelize` (logical) and `warning` (character or
#'   `NULL`).
#' @noRd
parallel_decision <- function(nthreads, ninteractive, omniscape_version,
                              requested) {
  if (nthreads < 2L) {
    return(list(
      parallelize = FALSE,
      warning = paste0(
        "parallelize = TRUE has no effect: Julia is running with 1 thread. ",
        "Running serially. ", thread_fix_hint(requested)
      )
    ))
  }
  if (isTRUE(ninteractive > 0L) &&
      !omniscape_handles_interactive_threads(omniscape_version)) {
    return(list(
      parallelize = FALSE,
      warning = paste0(
        "Julia was started with an interactive thread (JULIA_NUM_THREADS ",
        "set to \"N\" rather than \"N,0\"), which makes parallel runs of ",
        "Omniscape ", if (is.na(omniscape_version)) "" else
          paste0(omniscape_version, " "),
        "fail with a BoundsError. Running serially. ",
        thread_fix_hint(nthreads)
      )
    ))
  }
  if (nthreads < requested) {
    return(list(
      parallelize = TRUE,
      warning = paste0(
        "Julia is running with ", nthreads, " threads, not the ", requested,
        " requested; using ", nthreads, ". To use more, call ",
        "cs_setup(threads = ", requested, "), which restarts Julia."
      )
    ))
  }
  list(parallelize = TRUE, warning = NULL)
}
