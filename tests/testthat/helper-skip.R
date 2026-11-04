#' Skip test if Julia or Circuitscape is not available
#'
#' Set the environment variable CIRCUITSCAPER_REQUIRE_JULIA=true (as the
#' Julia integration CI job does) to make a missing or broken Julia setup fail
#' the test instead of skipping it, so integration tests can't silently skip.
skip_if_no_julia <- function() {
  require_julia <- identical(tolower(Sys.getenv("CIRCUITSCAPER_REQUIRE_JULIA")),
                             "true")
  if (!require_julia) skip_on_cran()
  if (!.cs_env$julia_ready) {
    tryCatch(
      cs_setup(quiet = TRUE),
      error = function(e) {
        if (require_julia) {
          stop("Julia setup failed but CIRCUITSCAPER_REQUIRE_JULIA is set: ",
               conditionMessage(e), call. = FALSE)
        }
        skip("Julia or Circuitscape/Omniscape not available")
      }
    )
  }
  if (!.cs_env$julia_ready) {
    if (require_julia) stop("Julia is not ready after cs_setup().", call. = FALSE)
    skip("Julia or Circuitscape/Omniscape not available")
  }
}
