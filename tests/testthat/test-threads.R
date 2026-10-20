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
  # e.g. Julia started by JuliaCall::julia_setup() before cs_setup(threads=)
  d <- parallel_decision(nthreads = 1L, maxthreadid = 2L,
                         omniscape_version = "0.6.2", requested = 15L)
  expect_false(d$parallelize)
  expect_match(d$warning, "running with 1 thread")
  expect_match(d$warning, "cs_setup(threads = 15)", fixed = TRUE)
  expect_match(d$warning, "JULIA_NUM_THREADS = \"15,0\"", fixed = TRUE)
})

test_that("an interactive thread forces a serial run on old Omniscape", {
  d <- parallel_decision(nthreads = 4L, maxthreadid = 5L,
                         omniscape_version = "0.6.2", requested = 4L)
  expect_false(d$parallelize)
  expect_match(d$warning, "interactive thread")
  expect_match(d$warning, "BoundsError")
  expect_match(d$warning, "JULIA_NUM_THREADS = \"4,0\"", fixed = TRUE)
})

test_that("an interactive thread is fine on Omniscape 0.6.3+", {
  d <- parallel_decision(nthreads = 4L, maxthreadid = 5L,
                         omniscape_version = "0.6.3", requested = 4L)
  expect_true(d$parallelize)
  expect_null(d$warning)
})

test_that("an unknown Omniscape version is treated as unsafe", {
  d <- parallel_decision(nthreads = 4L, maxthreadid = 5L,
                         omniscape_version = NA_character_, requested = 4L)
  expect_false(d$parallelize)
})

test_that("fewer threads than requested still runs in parallel, with a note", {
  d <- parallel_decision(nthreads = 4L, maxthreadid = 4L,
                         omniscape_version = "0.6.2", requested = 8L)
  expect_true(d$parallelize)
  expect_match(d$warning, "not the 8 requested")
})

test_that("a correctly configured session runs in parallel silently", {
  d <- parallel_decision(nthreads = 8L, maxthreadid = 8L,
                         omniscape_version = "0.6.2", requested = 2L)
  expect_true(d$parallelize)
  expect_null(d$warning)
})

test_that("thread mismatch message explains the cause and the fix", {
  msg <- thread_mismatch_message(1L, 15L)
  expect_match(msg, "threads = 15 has no effect", fixed = TRUE)
  expect_match(msg, "fixed when Julia starts")
  expect_match(msg, "JuliaCall::julia_setup()", fixed = TRUE)
  expect_match(msg, "JULIA_NUM_THREADS = \"15,0\"", fixed = TRUE)
})
