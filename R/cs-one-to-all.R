#' One-to-All Circuitscape Analysis
#'
#' For each focal node in turn, inject current at that node and ground all
#' other focal nodes simultaneously.
#'
#' @inheritParams cs_pairwise
#'
#' @details
#' One-to-all mode iterates over each focal node. In each iteration, the focal
#' node is injected with 1 amp of current and all remaining focal nodes are
#' simultaneously connected to ground. This produces a current map showing how
#' current spreads from that node through the landscape to reach the others.
#'
#' This mode is useful for mapping how well each site is connected to the rest
#' of the focal node network, emphasizing current dispersal from each source.
#' The cumulative map sums across all iterations and highlights cells that are
#' important for connectivity across the full set of nodes.
#'
#' @return A [terra::SpatRaster] with the following layers:
#' \describe{
#'   \item{cumulative_current}{Current flow summed across all iterations.}
#'   \item{current_\emph{N}}{Per-node current map for focal node \emph{N}, where
#'     \emph{N} is the integer node ID from the `locations` raster. One layer
#'     per focal node.}
#' }
#'
#' @references
#' Circuitscape user guide:
#' \url{https://docs.circuitscape.org/Circuitscape.jl/latest/usage/}
#'
#' @seealso [cs_pairwise()], [cs_all_to_one()], [cs_advanced()], [cs_setup()]
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
#' coords <- matrix(c(-140, 70, -60, 70, -100, 30), ncol = 2, byrow = TRUE)
#' result <- cs_one_to_all(res, coords)
#' plot(result)
#' }
#'
#' @export
cs_one_to_all <- function(resistance,
                          locations,
                          resistance_is = "resistances",
                          four_neighbors = FALSE,
                          short_circuit = NULL,
                          included_pairs = NULL,
                          solver = "cg+amg",
                          output_dir = NULL,
                          verbose = FALSE) {

  run_cs_mode("one-to-all",
              resistance = resistance,
              locations = locations,
              resistance_is = resistance_is,
              four_neighbors = four_neighbors,
              short_circuit = short_circuit,
              included_pairs = included_pairs,
              solver = solver,
              output_dir = output_dir,
              verbose = verbose)
}
