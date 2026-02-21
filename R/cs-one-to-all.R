#' One-to-All Circuitscape Analysis
#'
#' For each focal node, that node is the source and all others are grounds
#' simultaneously. Computes effective resistance and current flow maps.
#'
#' @inheritParams cs_pairwise
#'
#' @return A named list with:
#' \describe{
#'   \item{current_map}{A [terra::SpatRaster] with named layers for each output
#'     map.}
#'   \item{resistance_matrix}{A numeric matrix of effective resistances.}
#' }
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
#' locs <- rast(nrows = 10, ncols = 10, vals = 0)
#' locs[1, 1] <- 1; locs[10, 10] <- 2
#' result <- cs_one_to_all(res, locs)
#' plot(result$current_map)
#' }
#'
#' @export
cs_one_to_all <- function(resistance,
                          locations,
                          resistance_is = "resistances",
                          four_neighbors = FALSE,
                          solver = "cg+amg",
                          output_dir = NULL,
                          verbose = FALSE) {

  run_cs_mode("one-to-all",
              resistance = resistance,
              locations = locations,
              resistance_is = resistance_is,
              four_neighbors = four_neighbors,
              solver = solver,
              output_dir = output_dir,
              verbose = verbose)
}
