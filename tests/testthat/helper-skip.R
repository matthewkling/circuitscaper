#' Skip test if Julia or Circuitscape is not available
#'
#' Set the environment variable CIRCUITSCAPER_REQUIRE_JULIA=true (as the
#' Julia integration CI job does) to make a missing or broken Julia setup fail
#' the test instead of skipping it, so integration tests can't silently skip.
#'
#' A failed setup is remembered for the rest of the run, so later tests skip
#' at once instead of each waiting for Julia to time out. A failure with
#' `circuitscape = TRUE` may be the packages rather than Julia, so it doesn't
#' skip the tests that need only Julia.
skip_if_no_julia <- function(circuitscape = TRUE) {
  require_julia <- identical(tolower(Sys.getenv("CIRCUITSCAPER_REQUIRE_JULIA")),
                             "true")
  if (!require_julia) skip_on_cran()
  what <- if (circuitscape) "Julia or Circuitscape/Omniscape" else "Julia"
  level <- if (circuitscape) "circuitscape" else "julia"
  if (level %in% julia_skip_state$failed) {
    skip(paste(what, "not available (setup failed earlier in this run)"))
  }
  fail <- function(msg) {
    if (require_julia) {
      stop("Julia setup failed but CIRCUITSCAPER_REQUIRE_JULIA is set: ", msg,
           call. = FALSE)
    }
    # Without Julia, Circuitscape can't load either
    julia_skip_state$failed <- union(julia_skip_state$failed,
                                     if (circuitscape) level else c("julia", "circuitscape"))
    skip(paste(what, "not available"))
  }
  tryCatch(
    ensure_julia(circuitscape = circuitscape),
    error = function(e) fail(conditionMessage(e))
  )
  if (!.cs_env$julia_ready) fail("Julia is not ready after cs_setup().")
}

julia_skip_state <- new.env()
julia_skip_state$failed <- character(0)
