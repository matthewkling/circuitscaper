#' Pairwise Connectivity Among Focal Nodes From Random Dipoles
#'
#' Maps connectivity among every pair of a set of focal nodes, the
#' squared-current analogue of [cs_pairwise()]'s cumulative current map, at
#' a cost that doesn't grow with the number of nodes.
#'
#' @details
#' For each link \eqn{e} of the circuit (see [dp_circuit()]), the target is
#' \eqn{\sum_{i<j} I_e(i,j)^2}, over unordered pairs of focal nodes, where
#' \eqn{I_e(i,j)} is the current through \eqn{e} when one unit flows from
#' node \eqn{i} to node \eqn{j}. A cell's value is
#' \eqn{\sqrt{\frac{1}{2}\sum_{e \ni \mathrm{cell}} (\cdot)}} over its
#' links, as in [dp_omni()]. Pairs are counted only within groups of cells
#' connected to each other (no current passes across NA cells).
#'
#' With `method = "random"`, each draw injects
#' \eqn{\sum_{i<j} \xi_{ij}(e_i - e_j)}, every pair weighted by an
#' independent standard normal \eqn{\xi_{ij}}, and solves the circuit once;
#' the mean squared current over draws estimates the target without bias.
#' Its time hardly depends on the number of nodes (building each injection
#' takes \eqn{O(N^2)}, which is small next to a solve until \eqn{N} is in
#' the thousands). With `method = "exact"`, one solve per node gives the
#' exact target, using
#' \eqn{\sum_{i<j}(y_i - y_j)^2 = N\sum_i y_i^2 - (\sum_i y_i)^2} for each
#' link, with \eqn{y_i} its current when node \eqn{i} is the source.
#'
#' Unlike Circuitscape's cell maps, no current is added at focal nodes for
#' the current injected there.
#'
#' Reproducibility is as for [dp_omni()].
#'
#' @inheritParams dp_omni
#' @param locations The focal nodes: a two-column matrix or data frame of x
#'   and y coordinates (each snapped to the cell it falls in), or a
#'   [terra::SpatRaster] or file path on the same grid as `resistance` with
#'   a positive integer ID at each focal node's cell and 0 or NA elsewhere.
#'   Each node is one cell; focal regions of several cells aren't
#'   supported.
#' @param method Character. `"random"` (default) for random dipoles, or
#'   `"exact"` for the exact sum from one solve per node.
#' @param n_draws Integer. Number of draws (solves) for `method = "random"`.
#'   Default `32`.
#'
#' @return A [terra::SpatRaster] with one layer, `current`. Attributes:
#'   `"n_pairs"`, the number of pairs counted; for `method = "random"`, also
#'   `"halves"` (see [dp_omni()]) and `"seed"`.
#'
#' @seealso [cs_pairwise()], [dp_omni()], [dp_circuit()]
#'
#' @examplesIf circuitscaper::cs_julia_available()
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' set.seed(1)
#' nodes <- terra::spatSample(resistance, 30, xy = TRUE)[, 1:2]
#' result <- dp_pairwise(resistance, nodes, seed = 1)
#' exact <- dp_pairwise(resistance, nodes, method = "exact")
#' terra::plot(c(result, exact))
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_pairwise <- function(resistance, locations, method = c("random", "exact"),
                        resistance_is = "resistances", n_draws = 32, seed = NULL) {
  method <- match.arg(method)
  circuit <- dp_as_circuit(resistance, resistance_is)
  nodes <- dp_focal_nodes(circuit, locations)
  env <- circuit$env

  if (method == "exact") {
    res <- dp_call("pairwise_exact", env$id, nodes, 0L)
    dp_check_pairs(res$n_pairs)
    out <- dp_to_raster(circuit, sqrt(0.5 * res$cells[, 1]), "current")
  } else {
    n_draws <- dp_count(n_draws, "n_draws", min = 2)
    seed <- dp_seed(seed)
    res <- dp_call("pairwise_random", env$id, nodes, seed, n_draws, 0L)
    dp_check_pairs(res$n_pairs)
    n_half <- c(ceiling(n_draws / 2), floor(n_draws / 2))
    out <- dp_to_raster(circuit, sqrt(0.5 * rowSums(res$cells) / n_draws), "current")
    halves <- dp_halves(sqrt(0.5 * res$cells[, 1] / n_half[1]),
                        sqrt(0.5 * res$cells[, 2] / n_half[2]),
                        rep(TRUE, nrow(res$cells)))
    rownames(halves) <- "current"
    attr(out, "halves") <- halves
    attr(out, "seed") <- seed
  }
  attr(out, "n_pairs") <- res$n_pairs
  out
}

#' Focal Nodes as Circuit Node Numbers, in ID Order
#' @noRd
dp_focal_nodes <- function(circuit, locations) {
  tmpl <- circuit$env$template
  if (is.matrix(locations) || is.data.frame(locations)) {
    loc <- cs_locations(locations, tmpl)
  } else {
    loc <- dp_rast(locations, "locations")
    if (!isTRUE(terra::compareGeom(loc, tmpl, crs = FALSE, stopOnError = FALSE))) {
      stop("`locations` must have the same extent, resolution and number of ",
           "rows and columns as `resistance`.", call. = FALSE)
    }
  }
  v <- terra::values(loc, mat = FALSE)
  cells <- which(!is.na(v) & v > 0)
  ids <- v[cells]
  if (anyDuplicated(ids)) {
    stop("Each focal node must be a single cell; focal regions of several ",
         "cells aren't supported. Repeated ID(s): ",
         paste(utils::head(unique(ids[duplicated(ids)]), 10), collapse = ", "),
         call. = FALSE)
  }
  if (length(cells) < 2) {
    stop("At least 2 focal nodes are required.", call. = FALSE)
  }
  node <- match(cells, circuit$env$cells)
  if (anyNA(node)) {
    stop("Focal node(s) on cells outside the circuit (NA or zero ",
         "conductance), with ID(s): ",
         paste(utils::head(ids[is.na(node)], 10), collapse = ", "), call. = FALSE)
  }
  as.integer(node[order(ids)])
}

dp_check_pairs <- function(n_pairs) {
  if (n_pairs == 0) {
    stop("No two focal nodes are connected: each lies in a separate part of ",
         "the circuit.", call. = FALSE)
  }
}
