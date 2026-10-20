#' Number of Julia Threads in the Running Session
#'
#' @return Integer. The size of Julia's default thread pool.
#' @noRd
julia_nthreads <- function() {
  as.integer(JuliaCall::julia_eval("Threads.nthreads()"))
}


#' Thread Layout of the Running Julia Session
#'
#' @return List with `nthreads` (default pool size), `maxthreadid` (highest
#'   thread id, which exceeds `nthreads` when Julia has interactive threads),
#'   and `omniscape_version` (character, or `NA` if unavailable).
#' @noRd
julia_thread_info <- function() {
  nthreads <- julia_nthreads()
  maxthreadid <- tryCatch(
    as.integer(JuliaCall::julia_eval("Threads.maxthreadid()")),
    error = function(e) nthreads
  )
  omniscape_version <- tryCatch(
    as.character(JuliaCall::julia_eval("string(pkgversion(Omniscape))")),
    error = function(e) NA_character_
  )
  list(nthreads = nthreads, maxthreadid = maxthreadid,
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
    "To run in parallel, restart R and call cs_setup(threads = ", n, ") ",
    "before anything else starts Julia. If you start Julia yourself (for ",
    "example with JuliaCall::julia_setup()), first run ",
    "Sys.setenv(JULIA_NUM_THREADS = \"", n, ",0\")."
  )
}


#' Warning Text for a Thread Request Julia Can No Longer Honor
#' @param actual Threads Julia is running with.
#' @param requested Threads requested.
#' @noRd
thread_mismatch_message <- function(actual, requested) {
  paste0(
    "Julia is running with ", actual, " thread(s), so threads = ", requested,
    " has no effect. Julia's thread count is fixed when Julia starts, and ",
    "Julia was already running when this was requested (started, for ",
    "example, by JuliaCall::julia_setup() or an earlier circuitscaper ",
    "call). ", thread_fix_hint(requested)
  )
}


#' Decide Whether an Omniscape Run Can Use Julia's Threads
#'
#' Pure function of the session's thread layout, so it can be tested without
#' Julia.
#'
#' @param nthreads,maxthreadid,omniscape_version As from
#'   `julia_thread_info()`.
#' @param requested The `julia_threads` the user asked for.
#' @return List with `parallelize` (logical) and `warning` (character or
#'   `NULL`).
#' @noRd
parallel_decision <- function(nthreads, maxthreadid, omniscape_version,
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
  if (maxthreadid > nthreads &&
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
        " requested; using ", nthreads, ". Julia's thread count is fixed ",
        "when Julia starts."
      )
    ))
  }
  list(parallelize = TRUE, warning = NULL)
}
