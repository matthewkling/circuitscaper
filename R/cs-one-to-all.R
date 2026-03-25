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
#' McRae, B.H. (2006). Isolation by resistance. \emph{Evolution}, 60(8),
#' 1551--1561. \doi{10.1111/j.1558-5646.2006.tb00500.x}
#'
#' Circuitscape.jl: \url{https://docs.circuitscape.org/Circuitscape.jl/latest/}
#'
#' @seealso [cs_pairwise()], [cs_all_to_one()], [cs_advanced()], [cs_setup()]
#'
#' @examplesIf circuitscaper:::julia_check()
#' library(terra)
#' res <- rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
#' coords <- matrix(c(10, 40, 40, 40, 10, 10, 40, 10), ncol = 2, byrow = TRUE)
#' result <- cs_one_to_all(res, coords)
#' plot(result)
#'
#' @export
cs_one_to_all <- function(resistance,
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

  run_cs_mode("one-to-all",
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
