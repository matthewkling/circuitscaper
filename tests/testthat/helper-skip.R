#' Skip test if Julia or Circuitscape is not available
#'
#' Set the environment variable CIRCUITSCAPER_REQUIRE_JULIA=true (as the
#' Julia integration CI job does) to make a missing or broken Julia setup fail
#' the test instead of skipping it, so integration tests can't silently skip.
skip_if_no_julia <- function(circuitscape = TRUE) {
  require_julia <- identical(tolower(Sys.getenv("CIRCUITSCAPER_REQUIRE_JULIA")),
                             "true")
  if (!require_julia) skip_on_cran()
  what <- if (circuitscape) "Julia or Circuitscape/Omniscape" else "Julia"
  tryCatch(
    ensure_julia(circuitscape = circuitscape),
    error = function(e) {
      if (require_julia) {
        stop("Julia setup failed but CIRCUITSCAPER_REQUIRE_JULIA is set: ",
             conditionMessage(e), call. = FALSE)
      }
      skip(paste(what, "not available"))
    }
  )
  if (!.cs_env$julia_ready) {
    if (require_julia) stop("Julia is not ready after cs_setup().", call. = FALSE)
    skip(paste(what, "not available"))
  }
}
