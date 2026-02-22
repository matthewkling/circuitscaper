#' All-to-One Circuitscape Analysis
#'
#' For each focal node, all other nodes are sources and that node is the ground.
#' Computes effective resistance and current flow maps.
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
#' @references
#' Circuitscape user guide:
#' \url{https://docs.circuitscape.org/Circuitscape.jl/latest/usage/}
#'
#' @seealso [cs_pairwise()], [cs_one_to_all()], [cs_advanced()], [cs_setup()]
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
#' locs <- rast(nrows = 10, ncols = 10, vals = 0)
#' locs[1, 1] <- 1; locs[1, 10] <- 2; locs[10, 5] <- 3
#' result <- cs_all_to_one(res, locs)
#' plot(result$current_map)
#' }
#'
#' @export
cs_all_to_one <- function(resistance,
                          locations,
                          resistance_is = "resistances",
                          four_neighbors = FALSE,
                          solver = "cg+amg",
                          output_dir = NULL,
                          verbose = FALSE) {

  run_cs_mode("all-to-one",
              resistance = resistance,
              locations = locations,
              resistance_is = resistance_is,
              four_neighbors = four_neighbors,
              solver = solver,
              output_dir = output_dir,
              verbose = verbose)
}
