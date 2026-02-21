#' Skip test if Julia or Circuitscape is not available
skip_if_no_julia <- function() {
  skip_on_cran()
  if (!.cs_env$julia_ready) {
    tryCatch(
      cs_setup(quiet = TRUE),
      error = function(e) {
        skip("Julia or Circuitscape/Omniscape not available")
      }
    )
  }
  if (!.cs_env$julia_ready) {
    skip("Julia or Circuitscape/Omniscape not available")
  }
}
