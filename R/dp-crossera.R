#' Cross-Era Net Flux
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps the net flow of a range shift: present habitat injects current and
#' future habitat withdraws it, in fixed amounts, in one solve. The result
#' is signed, so it has direction.
#'
#' @details
#' The injection is \eqn{b = p / \sum p - f / \sum f}, with \eqn{p} and
#' \eqn{f} the present and future source strengths: one unit enters at
#' present habitat and leaves at future habitat, wherever it has to travel.
#' This is the minimum-energy flow that turns the present distribution into
#' the future one. Only the cell totals matter, not which present cell pairs
#' with which future cell, so there is no dispersal limit; show results
#' beside a dispersal-limited map such as [dp_pathways()]. Where present and
#' future habitat coincide, injection and withdrawal cancel, so net flux
#' mostly measures movement from lost to gained habitat.
#'
#' Withdrawals are fixed, not grounds: each future cell takes its share
#' however far away it is. (With grounds, as in [cs_advanced()], current
#' drains into the nearest future habitat instead.)
#'
#' Current can't cross NA cells, so the flow must balance within each group
#' of connected cells (component). Within a component holding present share
#' \eqn{P_c} and future share \eqn{F_c} of the totals, both are scaled to
#' \eqn{(P_c + F_c)/2}; components with no present or no future habitat
#' carry no flow. The share that would have had to move between components,
#' \eqn{\sum_c |P_c - F_c| / 2}, is returned as the `"imbalance"`
#' attribute, with a warning if it exceeds 1%.
#'
#' @inheritParams dp_omni
#' @param present,future [terra::SpatRaster]s or file paths on the same grid
#'   as `resistance`: present and future source strength, e.g. habitat
#'   suitability. NA counts as 0.
#' @param source_threshold Numeric. Cells with source strength below this
#'   are not sources (or sinks). Default `0.01`.
#' @param direction Logical. Also return the components of net flow.
#'   Default `TRUE`.
#'
#' @return A [terra::SpatRaster] with layers:
#' \describe{
#'   \item{current}{Half the sum of absolute current over a cell's links, as
#'     in Circuitscape's current maps (without the injection term).}
#'   \item{flow_x, flow_y}{(with `direction`) Net flow through the cell
#'     towards the east and the north, in grid directions: half the sum
#'     over the cell's links of the current along the link times its unit
#'     direction.}
#' }
#' Attribute `"imbalance"` (see Details).
#'
#' @seealso [dp_pathways()], [cs_advanced()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' present <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' future <- terra::flip(present, "horizontal")
#' result <- dp_flux(resistance, present, future)
#' terra::plot(result)
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_flux <- function(resistance, present, future, source_threshold = 0.01,
                    resistance_is = "resistances", direction = TRUE) {
  circuit <- dp_as_circuit(resistance, resistance_is)
  p <- dp_weights(circuit, present, source_threshold, "present")
  f <- dp_weights(circuit, future, source_threshold, "future")
  comp <- dp_call("components", circuit$env$id)
  p <- p / sum(p)
  f <- f / sum(f)
  P <- tapply(p, comp, sum)
  Fc <- tapply(f, comp, sum)
  both <- P > 0 & Fc > 0
  if (!any(both)) {
    stop("No connected part of the circuit holds both present and future ",
         "habitat, so there is no flow.", call. = FALSE)
  }
  target <- ifelse(both, (P + Fc) / 2, 0)
  k <- as.character(comp)
  b <- p * ifelse(P[k] > 0, target[k] / P[k], 0) -
    f * ifelse(Fc[k] > 0, target[k] / Fc[k], 0)
  imbalance <- sum(abs(P - Fc)) / 2
  if (imbalance > 0.01) {
    warning(sprintf(paste0(
      "%.1f%% of the flow would have to cross between parts of the circuit ",
      "that NA cells separate; it was dropped (see the \"imbalance\" ",
      "attribute)."), 100 * imbalance), call. = FALSE)
  }

  cells <- dp_call("flux", circuit$env$id, as.double(unname(b)))
  out <- if (isTRUE(direction)) {
    dp_to_raster(circuit, 0.5 * cells[, c(1, 3, 4)], c("current", "flow_x", "flow_y"))
  } else {
    dp_to_raster(circuit, 0.5 * cells[, 1], "current")
  }
  attr(out, "imbalance") <- imbalance
  out
}


#' Cross-Era Gross Pathways From Random Dipoles
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps the pathways that connect present habitat to future habitat within
#' dispersal reach: random-sign dipoles with one end in present habitat and
#' the other in future habitat. Magnitude only, without direction.
#'
#' @details
#' As [dp_omni()], with pairs \eqn{(i, j)} weighted by
#' \eqn{p_i f_j k(d_{ij})}: \eqn{i} in present habitat, \eqn{j} in future
#' habitat, within `radius` of each other. The pairing is one-way, but the
#' squared current of a pair is the same in both directions, so random
#' signs are valid. Stable habitat (suitable in both eras) takes part at
#' both ends, unlike in [dp_flux()]. See [dp_omni()] for the estimator,
#' accuracy, reproducibility and performance.
#'
#' @inheritParams dp_omni
#' @inheritParams dp_flux
#' @param normalize Logical. Also compute flow potential (the same dipoles
#'   on the uniform circuit) and normalized current. Default `TRUE`.
#'
#' @return As for [dp_omni()]. The `"halves"` diagnostic is over cells that
#'   are present or future sources.
#'
#' @seealso [dp_flux()], [dp_omni()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' present <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' future <- terra::flip(present, "horizontal")
#' result <- dp_pathways(resistance, present, future, radius = 20, seed = 1)
#' terra::plot(result)
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_pathways <- function(resistance, present, future, radius, source_threshold = 0.01,
                        radius_units = c("pixels", "km"), resistance_is = "resistances",
                        normalize = TRUE, n_draws = 32, n_dipoles = 1e5, seed = NULL) {
  radius_units <- match.arg(radius_units)
  n_draws <- dp_count(n_draws, "n_draws", min = 2)
  n_dipoles <- dp_count(n_dipoles, "n_dipoles")
  seed <- dp_seed(seed)
  normalize <- isTRUE(normalize)

  circuit <- dp_as_circuit(resistance, resistance_is, uniform = normalize)
  kernel <- dp_kernel(circuit$env$template, radius, radius_units)
  p <- dp_weights(circuit, present, source_threshold, "present")
  f <- dp_weights(circuit, future, source_threshold, "future")
  dp_random_map(circuit, p, f, kernel, seed, n_draws, n_dipoles, normalize,
                mask = p > 0 | f > 0)
}
