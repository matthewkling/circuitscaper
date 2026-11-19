#' Pairwise Connectivity Among Focal Nodes From Random Dipoles
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps connectivity among every pair of a set of focal nodes, the
#' squared-current analogue of [cs_pairwise()]'s cumulative current map, at
#' a cost that doesn't grow with the number of nodes.
#'
#' @details
#' Current flows along the circuit's links: the resistors joining each cell
#' to its 8 neighbours (see [dp_circuit()]). For each link \eqn{e}, the
#' target is
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
#' Current enters and leaves the circuit at the focal nodes, as in
#' Circuitscape, but cell values count only the current on links.
#' Circuitscape's cell maps also add the current injected or withdrawn at a
#' cell before halving, so that a focal node's value includes the full unit
#' it sends or receives; here, the current arriving from outside the circuit
#' isn't counted, so focal nodes' cells read lower than in [cs_pairwise()].
#' Other cells, where current both enters and leaves along links, are
#' unaffected.
#'
#' Flow potential is the same quantity on the uniform circuit (with the same
#' draws, for `method = "random"`), and normalized current is current
#' divided by it, as in [dp_omni()]. Normalizing takes a second
#' factorization and, for `method = "exact"`, a second set of solves.
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
#' @param normalize Logical. Also compute flow potential (the same pairs on
#'   the uniform circuit, conductance 1 on the same cells) and normalized
#'   current. Default `TRUE`.
#' @param n_draws Integer. Number of draws (solves) for `method = "random"`.
#'   Default `32`.
#'
#' @return A [terra::SpatRaster] with layers `current`; with `normalize`,
#'   `flow_potential` and `normalized_current`; with `power`, `power`; and
#'   with both, `normalized_power`, as in [dp_omni()]. With
#'   `method = "exact"`, `power` sums to the pairs' total effective
#'   resistance, the power each pair's unit current dissipates. Attributes:
#'   `"n_pairs"`, the number of pairs counted; for `method = "random"`, also
#'   `"halves"` (see [dp_omni()]) and `"seed"`.
#'
#' @seealso [cs_pairwise()], [dp_omni()], [dp_circuit()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' set.seed(1)
#' nodes <- terra::spatSample(resistance, 30, xy = TRUE)[, 1:2]
#' result <- dp_pairwise(resistance, nodes, seed = 1)
#' exact <- dp_pairwise(resistance, nodes, method = "exact")
#' terra::plot(c(result$normalized_current, exact$normalized_current))
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_pairwise <- function(resistance, locations, method = c("random", "exact"),
                        resistance_is = "resistances", normalize = TRUE,
                        n_draws = 32, seed = NULL, power = FALSE, progress = TRUE) {
  method <- match.arg(method)
  normalize <- isTRUE(normalize)
  power <- isTRUE(power)
  if (method == "random") {
    n_draws <- dp_count(n_draws, "n_draws", min = 2)
    seed <- dp_seed(seed)
  }
  input <- dp_circuit_input(resistance, resistance_is)
  solve_steps <- if (method == "exact") {
    1 + normalize
  } else {
    dp_draw_steps(input, n_draws, 1 + normalize)
  }
  p <- dp_progressor(progress, dp_factor_steps(input, normalize) + solve_steps)
  circuit <- dp_as_circuit(input, uniform = normalize, p = p)
  nodes <- dp_focal_nodes(circuit, locations)
  env <- circuit$env

  if (method == "exact") {
    res <- dp_call("pairwise_exact", env$id, nodes, 0L, dp_julia_progress(p), FALSE)
    dp_check_pairs(res$n_pairs)
    v <- list(cur2 = 0.5 * res$cells[, 1], pow = 0.5 * res$power[, 1])
    if (normalize) {
      u <- dp_call("pairwise_exact", env$uniform_id, nodes, 0L, dp_julia_progress(p), TRUE)
      v$fp2 <- 0.5 * u$cells[, 1]
      v$fpow <- 0.5 * u$power[, 1]
    }
    ratio <- function(a, b) ifelse(b > 0, sqrt(a / b), NA_real_)
    values <- cbind(current = sqrt(v$cur2))
    if (normalize) {
      values <- cbind(values, flow_potential = sqrt(v$fp2),
                      normalized_current = ratio(v$cur2, v$fp2))
    }
    if (power) {
      values <- cbind(values, power = v$pow)
      if (normalize) {
        values <- cbind(values, normalized_power = ifelse(v$fpow > 0, v$pow / v$fpow,
                                                          NA_real_))
      }
    }
    out <- dp_to_raster(circuit, values, colnames(values))
  } else {
    ids <- c(env$id, if (normalize) env$uniform_id)
    res <- dp_call("pairwise_random", as.integer(ids), nodes, seed, n_draws, 0L,
                   dp_julia_progress(p))
    dp_check_pairs(res$n_pairs)
    n_half <- c(ceiling(n_draws / 2), floor(n_draws / 2))
    sq <- function(cells) 0.5 * rowSums(cells) / n_draws
    halves <- function(cells) {
      cbind(0.5 * cells[, 1] / n_half[1], 0.5 * cells[, 2] / n_half[2])
    }
    v <- list(cur2 = sq(res$cells[[1]]), cur2_half = halves(res$cells[[1]]))
    if (normalize) {
      v$fp2 <- sq(res$cells[[2]])
      v$fp2_half <- halves(res$cells[[2]])
    }
    if (power) {
      v$pow <- sq(res$power[[1]])
      v$pow_half <- halves(res$power[[1]])
      if (normalize) {
        v$fpow <- sq(res$power[[2]])
        v$fpow_half <- halves(res$power[[2]])
      }
    }
    m <- dp_random_layers(v, normalize, rep(TRUE, length(v$cur2)))
    out <- dp_to_raster(circuit, m$values, colnames(m$values))
    attr(out, "halves") <- m$halves
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
