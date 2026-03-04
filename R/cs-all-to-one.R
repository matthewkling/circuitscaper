#' All-to-One Circuitscape Analysis
#'
#' For each focal node in turn, inject current at all other focal nodes and
#' ground that single node.
#'
#' @inheritParams cs_pairwise
#'
#' @details
#' All-to-one mode iterates over each focal node. In each iteration, all other
#' focal nodes are injected with 1 amp of current each, and the focal node is
#' connected to ground. This produces a current map showing how current
#' converges on that node from across the landscape.
#'
#' This mode is useful for identifying the most accessible or reachable sites
#' in the network, emphasizing current flow toward each ground node. The
#' cumulative map sums across all iterations and highlights cells that are
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
#' @seealso [cs_pairwise()], [cs_one_to_all()], [cs_advanced()], [cs_setup()]
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
#' coords <- matrix(c(-140, 70, -60, 70, -100, 30), ncol = 2, byrow = TRUE)
#' result <- cs_all_to_one(res, coords)
#' plot(result)
#' }
#'
#' @export
cs_all_to_one <- function(resistance,
                          locations,
                          resistance_is = "resistances",
                          four_neighbors = FALSE,
                          avg_resistances = FALSE,
                          short_circuit = NULL,
                          included_pairs = NULL,
                          write_voltage = FALSE,
                          cumulative_only = TRUE,
                          source_strengths = NULL,
                          solver = "cg+amg",
                          output_dir = NULL,
                          verbose = FALSE) {

  run_cs_mode("all-to-one",
              resistance = resistance,
              locations = locations,
              resistance_is = resistance_is,
              four_neighbors = four_neighbors,
              avg_resistances = avg_resistances,
              short_circuit = short_circuit,
              included_pairs = included_pairs,
              write_voltage = write_voltage,
              cumulative_only = cumulative_only,
              source_strengths = source_strengths,
              solver = solver,
              output_dir = output_dir,
              verbose = verbose)
}
