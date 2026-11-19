#' Directional and Undirected Flow Between Two Distributions
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps movement between an origin and a destination distribution both ways
#' at once, from the same pairs of cells: the directional map of
#' [dp_flux()], where flows in opposite directions cancel, and the
#' undirected map of [dp_omni()] with a `destination`, where they don't.
#' Their ratio, `directionality`, shows where movement between the two
#' distributions is one-way and where it runs both ways.
#'
#' @details
#' Current flows along the circuit's links: the resistors joining each cell
#' to its 8 neighbours (see [dp_circuit()]). Both maps sum over pairs of an
#' origin cell \eqn{i} and a destination cell \eqn{j}, with weights
#' \eqn{o_i d_j k(d_{ij})}: \eqn{o} and \eqn{d} are origin and destination
#' strength, and \eqn{k} is 1 for cells within `radius` of each other (in the
#' same component) and 0 otherwise. With \eqn{W} the total weight and
#' \eqn{I_e(i,j)} the current through link \eqn{e} when one unit flows from
#' \eqn{i} to \eqn{j}, the directional map is the pairs' weighted mean
#' current, \eqn{F_e = \sum_{i,j} o_i d_j k(d_{ij}) I_e(i,j) / W}, and the
#' undirected map their summed squared current,
#' \eqn{U_e = \sum_{i,j} o_i d_j k(d_{ij}) I_e(i,j)^2}.
#'
#' Since \eqn{U_e / W} is the pairs' weighted mean square current, the
#' ratio
#' \deqn{R_e = \frac{W F_e^2}{U_e} = 1 - \frac{\mathrm{Var}(I_e)}{\mathrm{E}[I_e^2]}}
#' is between 0 and 1. Like an \eqn{R^2}, it is the share of the pairs'
#' squared current that their mean flow accounts for, and so the share of
#' the power they dissipate in the link: 1 where all pairs cross the link in
#' the same direction, and near 0 where their flows cancel. A cell's
#' `directionality` is the same ratio over the links that meet at it,
#' \eqn{W \sum_e F_e^2 / \sum_e U_e}: the links' \eqn{R_e} averaged with
#' weights \eqn{U_e}.
#'
#' The directional map is exact; the undirected map is estimated from random
#' dipoles centered on the pairs' mean, as in [dp_omni()] with a
#' `destination`: the draws estimate only the variance of the pairs'
#' currents, and the mean's exact squared current is added back. So
#' `directionality` never exceeds 1, and its noise, about
#' \eqn{R (1 - R) \times 1.4 / \sqrt{\mathrm{n\_draws}}}, vanishes where
#' movement is one-way. (Without centering, it would be about
#' \eqn{R \times 1.4 / \sqrt{\mathrm{n\_draws}}}, and largest there.) It
#' is NA where the undirected current is zero.
#'
#' The layers are as from `dp_flux(cell_value = "rms")` and
#' `dp_omni(destination = )`, with the same arguments, but computed together:
#' one circuit, one set of pair weights, and one kernel.
#'
#' @inheritParams dp_flux
#' @inheritParams dp_omni
#' @param normalize Logical. Also compute flow potential and normalized
#'   current for both maps (on the uniform circuit, conductance 1 on the same
#'   cells). Default `TRUE`.
#'
#' @return A [terra::SpatRaster] with layers:
#' \describe{
#'   \item{directionality}{The ratio \eqn{R} above, between 0 and 1.}
#'   \item{flux_current}{The directional map's RMS current, as
#'     `dp_flux(cell_value = "rms")`'s `current`.}
#'   \item{flux_flow_potential, flux_normalized_current}{(with `normalize`)
#'     As `dp_flux()`'s `flow_potential` and `normalized_current`.}
#'   \item{flux_power, flux_normalized_power}{(with `power`; the second also
#'     needs `normalize`) As `dp_flux()`'s `power` and `normalized_power`.}
#'   \item{flow_x, flow_y}{Net flow through the cell towards the east and the
#'     north, as from [dp_flux()].}
#'   \item{omni_current}{The undirected map's current, as
#'     `dp_omni(destination = )`'s `current`.}
#'   \item{omni_flow_potential, omni_normalized_current}{(with `normalize`)
#'     As `dp_omni()`'s `flow_potential` and `normalized_current`.}
#'   \item{omni_power, omni_normalized_power}{(with `power`; the second also
#'     needs `normalize`) As `dp_omni()`'s `power` and `normalized_power`.}
#' }
#' Attributes: `"halves"`, comparing the estimates from odd and even draws
#' on origin and destination cells, as in [dp_omni()], for the undirected
#' layers and `directionality`; `"seed"`; and `"origin_in_reach"`,
#' `"destination_in_reach"` and `"pair_weight_in_reach"`, as in [dp_flux()]:
#' the first two say how much of each distribution has a counterpart within
#' reach, the third depends on the size of the domain relative to `radius`.
#'
#' @seealso [dp_flux()], [dp_omni()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
#' result <- dp_directionality(resistance, origin, destination, radius = 45,
#'                             normalize = FALSE, seed = 1)
#' terra::plot(result[[c("flux_current", "omni_current", "directionality")]])
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_directionality <- function(resistance, origin, destination, radius = Inf,
                              source_threshold = 0.01,
                              radius_units = c("pixels", "km"),
                              resistance_is = "resistances", normalize = TRUE,
                              n_draws = 32, n_dipoles = 1e5, seed = NULL,
                              power = FALSE, progress = TRUE) {
  radius_units <- match.arg(radius_units)
  n_draws <- dp_count(n_draws, "n_draws", min = 2)
  n_dipoles <- dp_count(n_dipoles, "n_dipoles")
  seed <- dp_seed(seed)
  normalize <- isTRUE(normalize)
  power <- isTRUE(power)

  input <- dp_circuit_input(resistance, resistance_is)
  p <- dp_progressor(progress, dp_factor_steps(input, normalize) + 1 + normalize +
                       dp_draw_steps(input, n_draws, 1 + normalize))
  circuit <- dp_as_circuit(input, uniform = normalize, p = p)
  kernel <- dp_kernel(circuit$env$template, radius, radius_units)
  o <- dp_weights(circuit, origin, source_threshold, "origin")
  d <- dp_weights(circuit, destination, source_threshold, "destination")
  mask <- o > 0 | d > 0

  f <- dp_flux_values(circuit, o, d, kernel, normalize, "rms", p = p)
  u <- dp_random_values(circuit, o, d, kernel, seed, n_draws, n_dipoles, normalize,
                        center = f, power = power, p = p)
  omni <- dp_random_layers(u, normalize, mask)

  share <- function(cur2) ifelse(cur2 > 0, f$W * f$current^2 / cur2, NA_real_)
  v <- cbind(directionality = share(u$cur2), flux_current = f$current)
  if (normalize) {
    v <- cbind(v, flux_flow_potential = f$fp, flux_normalized_current = f$nc)
  }
  if (power) {
    v <- cbind(v, flux_power = f$power)
    if (normalize) v <- cbind(v, flux_normalized_power = f$np)
  }
  v <- cbind(v, flow_x = f$flow[, 1], flow_y = f$flow[, 2])
  ov <- omni$values
  colnames(ov) <- paste0("omni_", colnames(ov))
  v <- cbind(v, ov)

  halves <- omni$halves
  rownames(halves) <- paste0("omni_", rownames(halves))
  halves <- rbind(halves, directionality = dp_halves(share(u$cur2_half[, 1]),
                                                     share(u$cur2_half[, 2]), mask))

  out <- dp_to_raster(circuit, v, colnames(v))
  attr(out, "halves") <- halves
  attr(out, "seed") <- seed
  dp_set_coverage(out, f)
}
