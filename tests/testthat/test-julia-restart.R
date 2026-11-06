# Recovering from a Julia process that went away, and restarting Julia for
# a thread request. The first tests mock the Julia calls, so they run
# without Julia; the last two use the real Julia.

# Replace circuitscaper's Julia state until the calling test ends.
local_cs_env <- function(..., .env = parent.frame()) {
  old <- as.list(.cs_env, all.names = TRUE)
  list2env(list(...), envir = .cs_env)
  withr::defer({
    rm(list = ls(.cs_env, all.names = TRUE), envir = .cs_env)
    list2env(old, envir = .cs_env)
  }, envir = .env)
}

# Mock the Julia process: julia_session_state() returns `state`, and calls
# to jl_stop() and init_julia() are recorded in the returned environment.
local_mock_julia <- function(state = "ready", .env = parent.frame()) {
  calls <- new.env()
  calls$stop <- 0L
  calls$init <- list()
  local_mocked_bindings(
    julia_session_state = function() state,
    jl_stop = function() {
      calls$stop <- calls$stop + 1L
      invisible()
    },
    init_julia = function(julia_home = NULL, threads = 1L, quiet = TRUE) {
      calls$init <- c(calls$init,
                      list(list(threads = threads,
                                ready = .cs_env$julia_ready)))
      invisible(TRUE)
    },
    .env = .env
  )
  calls
}

test_that("cs_setup() returns at once when its Julia is still running", {
  local_cs_env(julia_ready = TRUE, julia_threads = 1L, julia_interactive = 0L)
  calls <- local_mock_julia("ready")
  expect_true(cs_setup())
  expect_identical(calls$stop, 0L)
  expect_length(calls$init, 0)
})

test_that("cs_setup() sets Julia up again after Julia went away", {
  # A broken connection is closed before Julia is started again
  local_cs_env(julia_ready = TRUE, julia_threads = 1L, julia_interactive = 0L)
  calls <- local_mock_julia("broken")
  cs_setup()
  expect_identical(calls$stop, 1L)
  expect_length(calls$init, 1)
  expect_false(calls$init[[1]]$ready)

  # A new, bare Julia (e.g. after JuliaConnectoR::stopJulia()) is reused
  local_cs_env(julia_ready = TRUE, julia_threads = 1L, julia_interactive = 0L)
  calls <- local_mock_julia("fresh")
  cs_setup()
  expect_identical(calls$stop, 0L)
  expect_length(calls$init, 1)
})

test_that("cs_setup(threads = ) restarts a Julia with too few threads", {
  local_cs_env(julia_ready = TRUE, julia_threads = 1L, julia_interactive = 0L)
  calls <- local_mock_julia("ready")
  expect_message(cs_setup(threads = 4), "Restarting Julia with 4 threads")
  expect_identical(calls$stop, 1L)
  expect_identical(calls$init[[1]]$threads, 4L)
  expect_false(calls$init[[1]]$ready)

  # ... but not when it already has enough
  local_cs_env(julia_ready = TRUE, julia_threads = 4L, julia_interactive = 0L)
  calls <- local_mock_julia("ready")
  expect_no_message(cs_setup(threads = 2))
  expect_identical(calls$stop, 0L)
  expect_length(calls$init, 0)
})

test_that("julia_session_state() tells set-up, bare, and broken Julia apart", {
  local_mocked_bindings(jl_eval = function(expr) TRUE)
  expect_identical(julia_session_state(), "ready")
  local_mocked_bindings(jl_eval = function(expr) FALSE)
  expect_identical(julia_session_state(), "fresh")
  local_mocked_bindings(jl_eval = function(expr) stop("connection closed"))
  expect_identical(julia_session_state(), "broken")
})

test_that("forget_julia() resets circuitscaper's Julia state", {
  local_cs_env(julia_ready = TRUE, julia_threads = 4L, julia_interactive = 1L,
               loaded_packages = c("Circuitscape", "Omniscape"))
  stopped <- FALSE
  local_mocked_bindings(jl_stop = function() stopped <<- TRUE)
  forget_julia(stop = TRUE)
  expect_true(stopped)
  expect_false(.cs_env$julia_ready)
  expect_identical(.cs_env$julia_threads, 1L)
  expect_identical(.cs_env$julia_interactive, 0L)
  expect_length(.cs_env$loaded_packages, 0)
})

test_that("circuitscaper recovers when Julia is stopped", {
  skip_if_no_julia()
  JuliaConnectoR::stopJulia()
  expect_message(cs_setup(), "Initializing Julia")
  expect_identical(julia_session_state(), "ready")
  expect_true(.cs_env$julia_ready)
  expect_true(isTRUE(jl_eval("isdefined(Main, :Omniscape)")))
})

test_that("cs_setup(threads = ) restarts Julia with more threads", {
  skip_if_no_julia()
  n <- .cs_env$julia_threads + 1L
  expect_message(cs_setup(threads = n), "Restarting Julia")
  expect_true(.cs_env$julia_ready)
  expect_identical(julia_nthreads(), n)
  expect_identical(julia_ninteractive(), 0L)
  expect_identical(.cs_env$julia_threads, n)
})
