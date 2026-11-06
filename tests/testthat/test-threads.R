# Thread-layout decisions for parallel Omniscape runs. These are pure
# functions of the session's thread layout, so they run without Julia.

test_that("Omniscape version check handles releases, suffixes, and NA", {
  expect_false(omniscape_handles_interactive_threads("0.6.2"))
  expect_true(omniscape_handles_interactive_threads("0.6.3"))
  expect_true(omniscape_handles_interactive_threads("0.7.0-DEV"))
  expect_true(omniscape_handles_interactive_threads("1.0.0+build.1"))
  expect_false(omniscape_handles_interactive_threads(NA_character_))
  expect_false(omniscape_handles_interactive_threads("not a version"))
})

test_that("a single-threaded session runs serially with a fix hint", {
  # e.g. Julia started by another package before cs_setup(threads=)
  d <- parallel_decision(nthreads = 1L, ninteractive = 1L,
                         omniscape_version = "0.6.2", requested = 15L)
  expect_false(d$parallelize)
  expect_match(d$warning, "running with 1 thread")
  expect_match(d$warning, "cs_setup(threads = 15)", fixed = TRUE)
  expect_match(d$warning, "restarts Julia with 15 threads")
})

test_that("an interactive thread forces a serial run on old Omniscape", {
  d <- parallel_decision(nthreads = 4L, ninteractive = 1L,
                         omniscape_version = "0.6.2", requested = 4L)
  expect_false(d$parallelize)
  expect_match(d$warning, "interactive thread")
  expect_match(d$warning, "BoundsError")
  expect_match(d$warning, "cs_setup(threads = 4)", fixed = TRUE)
})

test_that("an interactive thread is fine on Omniscape 0.6.3+", {
  d <- parallel_decision(nthreads = 4L, ninteractive = 1L,
                         omniscape_version = "0.6.3", requested = 4L)
  expect_true(d$parallelize)
  expect_null(d$warning)
})

test_that("an unknown Omniscape version is treated as unsafe", {
  d <- parallel_decision(nthreads = 4L, ninteractive = 1L,
                         omniscape_version = NA_character_, requested = 4L)
  expect_false(d$parallelize)
})

test_that("fewer threads than requested still runs in parallel, with a note", {
  d <- parallel_decision(nthreads = 4L, ninteractive = 0L,
                         omniscape_version = "0.6.2", requested = 8L)
  expect_true(d$parallelize)
  expect_match(d$warning, "not the 8 requested")
})

test_that("a correctly configured session runs in parallel silently", {
  d <- parallel_decision(nthreads = 8L, ninteractive = 0L,
                         omniscape_version = "0.6.2", requested = 2L)
  expect_true(d$parallelize)
  expect_null(d$warning)
})

test_that("GC threads don't block parallel runs on old Omniscape", {
  # e.g. JULIA_NUM_THREADS = "20,0": maxthreadid() is 39 (20 default + 19
  # GC mark threads), but no interactive thread, so worker ids stay <= 20
  d <- parallel_decision(nthreads = 20L, ninteractive = 0L,
                         omniscape_version = "0.6.2", requested = 20L)
  expect_true(d$parallelize)
  expect_null(d$warning)
})

test_that("an unknown interactive pool size doesn't block a parallel run", {
  d <- parallel_decision(nthreads = 4L, ninteractive = NA_integer_,
                         omniscape_version = "0.6.2", requested = 4L)
  expect_true(d$parallelize)
})

test_that("thread mismatch message points at what else sets threads", {
  msg <- thread_mismatch_message(1L, 15L)
  expect_match(msg, "started with 1 thread(s) rather than the 15", fixed = TRUE)
  expect_match(msg, "JULIA_NUM_THREADS = \"15,0\"", fixed = TRUE)
  expect_match(msg, "JULIACONNECTOR_JULIAOPTS")
})

test_that("Julia is restarted only when it can't honor a thread request", {
  expect_true(julia_needs_restart(4L, nthreads = 1L, ninteractive = 0L))
  expect_true(julia_needs_restart(4L, nthreads = 2L, ninteractive = 0L))
  # An interactive thread breaks parallel runs of Omniscape < 0.6.3
  expect_true(julia_needs_restart(4L, nthreads = 4L, ninteractive = 1L))
  expect_false(julia_needs_restart(4L, nthreads = 4L, ninteractive = 0L))
  # Fewer threads than Julia has, or one thread, never restarts
  expect_false(julia_needs_restart(2L, nthreads = 4L, ninteractive = 0L))
  expect_false(julia_needs_restart(1L, nthreads = 4L, ninteractive = 1L))
  # Unknown interactive count doesn't force a restart
  expect_false(julia_needs_restart(4L, nthreads = 4L, ninteractive = NA))
})
