#' Compare Two Omniscape Runs
#'
#' Convenience function for comparing two Omniscape results, e.g., current vs.
#' future climate scenarios. Computes the difference and ratio between a
#' specified layer from each run.
#'
#' @param baseline A [terra::SpatRaster] result from [os_run()].
#' @param future A [terra::SpatRaster] result from [os_run()].
#' @param metric Character. Layer name to compare. Default
#'   `"normalized_current"`.
#'
#' @return A [terra::SpatRaster] with two layers:
#' \describe{
#'   \item{difference}{`future - baseline`}
#'   \item{ratio}{`future / baseline`}
#' }
#'
#' @examples
#' \dontrun{
#' baseline <- os_run(resistance_current, radius = 50)
#' future <- os_run(resistance_future, radius = 50)
#' comparison <- os_compare(baseline, future)
#' plot(comparison[["difference"]])
#' plot(comparison[["ratio"]])
#' }
#'
#' @export
os_compare <- function(baseline, future, metric = "normalized_current") {
  if (!inherits(baseline, "SpatRaster")) {
    stop("`baseline` must be a SpatRaster (output from os_run()).", call. = FALSE)
  }
  if (!inherits(future, "SpatRaster")) {
    stop("`future` must be a SpatRaster (output from os_run()).", call. = FALSE)
  }

  baseline_names <- names(baseline)
  future_names <- names(future)

  if (!metric %in% baseline_names) {
    stop("Layer '", metric, "' not found in baseline. Available layers: ",
         paste(baseline_names, collapse = ", "), call. = FALSE)
  }
  if (!metric %in% future_names) {
    stop("Layer '", metric, "' not found in future. Available layers: ",
         paste(future_names, collapse = ", "), call. = FALSE)
  }

  b <- baseline[[metric]]
  f <- future[[metric]]

  validate_raster_match(b, f, "baseline", "future")

  difference <- f - b
  ratio <- f / b

  result <- c(difference, ratio)
  names(result) <- c("difference", "ratio")
  result
}
