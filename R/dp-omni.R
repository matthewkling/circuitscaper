#' Omnidirectional Connectivity From Random Dipoles
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps omnidirectional connectivity among habitat, in the role of
#' [os_run()], with the random-dipole method: many random source-sink pairs
#' superposed on one factored circuit, which takes about `n_draws` solves
#' whatever the number of pairs.
#'
#' With a `destination`, it maps connectivity between two distributions
#' instead: the routes linking origin cells (`source_strength`) to
#' destination cells within `radius`, for example present to future habitat,
#' breeding to wintering grounds, or foraging to roosting habitat. The map is
#' undirected: every pair counts whichever way it flows, so swapping the two
#' surfaces gives the same map. For the net flow from one to the other, with
#' its direction, see [dp_flux()].
#'
#' @details
#' Current flows along the circuit's links: the resistors joining each cell
#' to its 8 neighbours (see [dp_circuit()]). For each link \eqn{e}, the
#' method estimates
#' \deqn{T_e = \sum_{i \ne j} w_i w_j k(d_{ij}) I_e(i,j)^2}
#' over ordered pairs of cells, where \eqn{w} is source strength, \eqn{k} is
#' 1 for cells within `radius` of each other and 0 otherwise, and
#' \eqn{I_e(i,j)} is the current through \eqn{e} when one unit flows from
#' \eqn{i} to \eqn{j} on the whole circuit. A cell's current combines the
#' links that meet at it, up to 8:
#' \eqn{\sqrt{\frac{1}{2}\sum_{e \ni \mathrm{cell}} T_e}}, where the half
#' is because each link is shared by the two cells it joins. For a unit flow,
#' a link's squared current is the derivative of the pair's effective
#' resistance with respect to that link's resistance, so the map is the
#' sensitivity of habitat-weighted pairwise resistance to degrading each
#' cell.
#'
#' With a `destination`, the pair weights are \eqn{o_i d_j k(d_{ij})}, with
#' \eqn{o} the origin (`source_strength`) and \eqn{d} the destination
#' strength. Since \eqn{I_e(i,j)^2 = I_e(j,i)^2}, only the unordered pairs
#' matter, and the map is the same whichever surface is the origin. A cell's
#' pair with itself carries no current. Cells in both distributions take
#' part at both ends, unlike in [dp_flux()], where their flow cancels. With
#' one surface, \eqn{o = d = w}.
#'
#' With two surfaces, the pairs have a mean dipole, whose current (the
#' directional map of [dp_flux()]) is solved exactly. Each draw's dipoles
#' are centered on it, so the draws estimate only the variance of the pairs'
#' currents, and the mean's exact squared current is added back. The
#' estimate is still unbiased, but where the pairs' currents mostly agree in
#' direction its noise is much smaller: by a factor of about \eqn{1 - R},
#' with \eqn{R} as in [dp_directionality()]. With one surface, the mean
#' dipole is zero.
#'
#' Each draw injects `n_dipoles` unit dipoles, pairs drawn in proportion to
#' \eqn{w_i w_j k(d_{ij})}, each with a random sign, and solves the circuit
#' once. The random signs make the cross terms between dipoles average out,
#' so the mean squared current over draws, scaled by
#' \eqn{S / M} (\eqn{S} the sum of pair weights, \eqn{M} = `n_dipoles`),
#' estimates \eqn{T_e} without bias. Values don't depend on `n_dipoles`,
#' and runs with different settings are comparable.
#'
#' Pairs never span groups of cells that are separated by NA cells, since
#' no current can pass between them. Cells with source strength below
#' `source_threshold`, or NA, are not sources.
#'
#' Flow potential is the same estimate on the uniform circuit (conductance
#' 1 on the same cells) with the same dipoles, and normalized current is
#' current divided by flow potential: above 1 where current is channelled,
#' below 1 where it is impeded. Unlike [os_run()], flow potential uses the
#' same circuit shape as current, not a square box per target.
#'
#' The result differs from [os_run()]'s by design: squared rather than
#' absolute current, and the whole circuit rather than a window around each
#' target. Current maps typically agree closely (Spearman's
#' \eqn{\rho \approx} 0.95--0.99), normalized current less so
#' (\eqn{\rho \approx} 0.85). No current is added at endpoints for the
#' injected current itself, unlike Circuitscape's cell maps.
#'
#' ## Power
#' With `power = TRUE`, the result also maps the power dissipated, which
#' picks out choke points: places where current is forced through
#' resistance. A link's power is its squared current (summed over pairs, as
#' for `current`) times its resistance, \eqn{1 / g_e}. A cell's `power` is
#' half the sum over its links, so each link's power is shared between the
#' two cells it joins, and the cells sum to the circuit's total. It comes
#' from the same per-link sums as `current`, so it costs no extra solves,
#' and its estimate is unbiased with about twice the relative noise of
#' `current`.
#'
#' This is not `current` squared times the cell's resistance. A link's
#' resistance depends on both cells it joins (with Circuitscape's averaged
#' conductances, it approaches twice the lower of the two resistances where
#' they differ widely), and diagonal links' resistance is \eqn{\sqrt{2}}
#' times larger. Squaring a current map and multiplying by resistance
#' overstates power on high-resistance cells next to low-resistance ones,
#' where choke points often are.
#'
#' With `normalize`, `normalized_power` is power divided by the power of
#' the same pairs on the uniform circuit. Unlike normalized current, it has
#' the units of resistance (the uniform circuit's links have resistance 1),
#' so compare it within a surface rather than across surfaces in different
#' units.
#'
#' ## Accuracy
#' Each draw contributes noise with a relative standard deviation of about
#' 1.4, so per-cell noise falls as \eqn{1/\sqrt{\mathrm{n\_draws}}}: in
#' tests at the default 32 draws, about 6--12% in current and 3--10% in
#' normalized current. More dipoles per draw help only until pairs are well covered
#' (about \eqn{10^5}). The `"halves"` attribute compares estimates from the
#' odd and even draws, an estimate of the noise of a run.
#'
#' ## Reproducibility
#' Results are determined by `seed`, the settings and the circuit: each
#' draw has its own random stream, so they don't depend on the number of
#' Julia threads (beyond the last bits of rounding, which can depend on the
#' linear algebra library's threading). Random streams can change between
#' Julia versions.
#'
#' ## Performance
#' The time is mostly the factorization (one, or two with `normalize`) and
#' the solves; it barely depends on `radius`. Draws are sampled and link
#' currents summed in parallel over Julia's threads; set the number with
#' [cs_setup()]. To reuse factorizations across runs, pass a circuit from
#' [dp_circuit()].
#'
#' ## Progress
#' The dipole functions report progress through the 'progressr' package:
#' one step per factorization and, for each batch of draws, one for sampling
#' its dipoles and one per circuit solved (current, and with `normalize`,
#' flow potential), plus one per solve of the mean flow with a
#' `destination`. Draws are solved in batches of 8 to 32 (fewer on larger
#' grids), so at the default 32 draws most runs are one batch. Nothing is
#' shown unless a handler is active, e.g.
#' `progressr::with_progress(dp_omni(...))` or, in a 'shiny' app,
#' `progressr::withProgressShiny(dp_omni(...))`; see [progressr::handlers()].
#' Reporting doesn't change the results. Set `progress = FALSE` to signal
#' nothing at all.
#'
#' @param resistance A [terra::SpatRaster] or file path: the resistance (or
#'   conductance) surface. Or a circuit from [dp_circuit()], to reuse its
#'   factorization.
#' @param radius Numeric. The dispersal radius: pairs of cells are counted
#'   if their centres are at most this far apart. In pixels by default (see
#'   `radius_units`). `Inf` counts all pairs.
#' @param source_strength Optional [terra::SpatRaster] or file path on the
#'   same grid: source strength, e.g. habitat suitability. If `NULL`
#'   (default), the conductance surface is used, as in [os_run()]. With a
#'   `destination`, this is the origin strength.
#' @param destination Optional [terra::SpatRaster] or file path on the same
#'   grid: destination strength, e.g. habitat suitability in another period
#'   or season. If given, only pairs of an origin and a destination cell
#'   count. Default `NULL`: pairs of cells of one surface.
#' @param source_threshold Numeric. Cells with source (or destination)
#'   strength below this are not sources (or destinations). Default `0.01`.
#' @param radius_units Character. `"pixels"` (default): the radius counts
#'   cells, so the kernel is the cells with \eqn{dr^2 + dc^2 \le}
#'   `radius`\eqn{^2}, as in [os_run()]. `"km"`: great-circle distance
#'   between cell centres on lon/lat grids (the kernel narrows in degrees
#'   of longitude towards the poles), or distance in the coordinate
#'   reference system's units, converted to km, on projected grids.
#' @param resistance_is Character. Whether `resistance` holds
#'   `"resistances"` (default) or `"conductances"`. Ignored for a circuit.
#' @param normalize Logical. Also compute flow potential and normalized
#'   current. Default `TRUE`.
#' @param n_draws Integer. Number of draws (solves). Default `32`.
#' @param n_dipoles Integer. Number of dipoles per draw. Default `1e5`.
#' @param seed Integer or `NULL`. Seed for the random draws. If `NULL`
#'   (default), one is drawn from R's random number generator, so
#'   [set.seed()] also makes runs reproducible. The seed used is returned
#'   as the `"seed"` attribute.
#' @param power Logical. Also map the power dissipated (see "Power" in
#'   [dp_omni()]), and with `normalize`, normalized power. Default `FALSE`.
#' @param progress Logical. Report progress through the 'progressr'
#'   package (see "Progress" in [dp_omni()]). Default `TRUE`; it shows only
#'   when a 'progressr' handler is active.
#'
#' @return A [terra::SpatRaster] with layers `current`; with `normalize`,
#'   `flow_potential` and `normalized_current`; with `power`, `power`; and
#'   with both, `normalized_power`. Attributes: `"halves"`, a data frame
#'   comparing the estimates from odd and even draws on source (and
#'   destination) cells (Spearman's \eqn{\rho} and the median relative
#'   difference), for `current` and the normalized and power layers; and
#'   `"seed"`.
#'
#' @seealso [dp_circuit()], [dp_pairwise()], [dp_flux()], [os_run()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' result <- dp_omni(resistance, radius = 15, seed = 1)
#' terra::plot(result)
#' attr(result, "halves")
#'
#' # Connectivity between two distributions
#' origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
#' between <- dp_omni(resistance, radius = 45, source_strength = origin,
#'                    destination = destination, seed = 1)
#' terra::plot(between)
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_omni <- function(resistance, radius, source_strength = NULL,
                    destination = NULL, source_threshold = 0.01,
                    radius_units = c("pixels", "km"), resistance_is = "resistances", normalize = TRUE,
                    n_draws = 32, n_dipoles = 1e5, seed = NULL, power = FALSE,
                    progress = TRUE) {
  radius_units <- match.arg(radius_units)
  n_draws <- dp_count(n_draws, "n_draws", min = 2)
  n_dipoles <- dp_count(n_dipoles, "n_dipoles")
  seed <- dp_seed(seed)
  normalize <- isTRUE(normalize)
  power <- isTRUE(power)

  input <- dp_circuit_input(resistance, resistance_is)
  p <- dp_progressor(progress, dp_factor_steps(input, normalize) +
                       (!is.null(destination)) * (1 + normalize) +
                       dp_draw_steps(input, n_draws, 1 + normalize))
  circuit <- dp_as_circuit(input, uniform = normalize, p = p)
  kernel <- dp_kernel(circuit$env$template, radius, radius_units)
  w <- dp_weights(circuit, source_strength, source_threshold, "source_strength")
  if (is.null(destination)) {
    return(dp_random_map(circuit, w, w, kernel, seed, n_draws, n_dipoles,
                         normalize, mask = w > 0, power = power, p = p))
  }
  w2 <- dp_weights(circuit, destination, source_threshold, "destination")
  center <- dp_flux_values(circuit, w, w2, kernel, normalize, "rms", check = FALSE,
                           p = p)
  dp_random_map(circuit, w, w2, kernel, seed, n_draws, n_dipoles, normalize,
                mask = w > 0 | w2 > 0, center = center, power = power, p = p)
}


#' Squared Cell Currents From Random-Sign Dipoles
#'
#' Runs the draws and scales the per-node sums by S / M. Returns per-node
#' squared current `cur2` (half the sum over a node's links), its odd- and
#' even-draw estimates `cur2_half` (two columns), and with `normalize`, the
#' same for flow potential (`fp2`, `fp2_half`).
#'
#' With `center`, from `dp_flux_values(cell_value = "rms")` for the same
#' pairs, the dipoles are centered on their mean, so the draws estimate the
#' variance of the pairs' currents, and the mean's exact squared current is
#' added back: \eqn{W^2 / S} times the flux map's squared RMS current.
#' @param p A progressor, or `NULL` (see `dp_draw_steps()`).
#' @noRd
dp_random_values <- function(circuit, w1, w2, kernel, seed, n_draws, n_dipoles,
                             normalize, center = NULL, power = FALSE, p = NULL) {
  res <- dp_random_dipoles(circuit, w1, w2, kernel, seed, n_draws, n_dipoles,
                           uniform = normalize, center = center, p = p)
  if (res$S <= 0) {
    stop("No pairs of cells can be drawn: no two source cells (or origin and ",
         "destination cells) are within `radius` of each other in the same ",
         "connected part of the circuit.", call. = FALSE)
  }
  scale <- res$S / n_dipoles
  n_half <- c(ceiling(n_draws / 2), floor(n_draws / 2))
  sq <- function(cells) 0.5 * scale * rowSums(cells) / n_draws
  halves <- function(cells) {
    cbind(0.5 * scale * cells[, 1] / n_half[1], 0.5 * scale * cells[, 2] / n_half[2])
  }
  out <- list(cur2 = sq(res$cells[[1]]), cur2_half = halves(res$cells[[1]]))
  if (normalize) {
    out$fp2 <- sq(res$cells[[2]])
    out$fp2_half <- halves(res$cells[[2]])
  }
  if (power) {
    out$pow <- sq(res$power[[1]])
    out$pow_half <- halves(res$power[[1]])
    if (normalize) {
      out$fpow <- sq(res$power[[2]])
      out$fpow_half <- halves(res$power[[2]])
    }
  }
  if (!is.null(center)) {
    k <- center$W^2 / res$S
    out$cur2 <- out$cur2 + k * center$current^2
    out$cur2_half <- out$cur2_half + k * center$current^2
    if (normalize) {
      out$fp2 <- out$fp2 + k * center$fp^2
      out$fp2_half <- out$fp2_half + k * center$fp^2
    }
    if (power) {
      out$pow <- out$pow + k * center$power
      out$pow_half <- out$pow_half + k * center$power
      if (normalize) {
        out$fpow <- out$fpow + k * center$fp_power
        out$fpow_half <- out$fpow_half + k * center$fp_power
      }
    }
  }
  out
}

#' Map From Random-Sign Dipoles
#'
#' RMS cell values from `dp_random_values()`, as a raster with the halves
#' diagnostic over `mask`.
#' @noRd
dp_random_map <- function(circuit, w1, w2, kernel, seed, n_draws, n_dipoles,
                          normalize, mask, center = NULL, power = FALSE, p = NULL) {
  v <- dp_random_values(circuit, w1, w2, kernel, seed, n_draws, n_dipoles, normalize,
                        center, power, p)
  m <- dp_random_layers(v, normalize, mask)
  out <- dp_to_raster(circuit, m$values, colnames(m$values))
  attr(out, "halves") <- m$halves
  attr(out, "seed") <- seed
  out
}

#' Current, Flow Potential and Normalized Current From Squared Values
#'
#' Returns `values`, a matrix with columns `current` and, with `normalize`,
#' `flow_potential` and `normalized_current`; and `halves`, the halves
#' diagnostic for current and normalized current.
#' @noRd
dp_random_layers <- function(v, normalize, mask) {
  ratio <- function(a, b) ifelse(b > 0, sqrt(a / b), NA_real_)
  values <- cbind(current = sqrt(v$cur2))
  halves <- dp_halves(sqrt(v$cur2_half[, 1]), sqrt(v$cur2_half[, 2]), mask)
  rownames(halves) <- "current"
  if (normalize) {
    values <- cbind(values, flow_potential = sqrt(v$fp2),
                    normalized_current = ratio(v$cur2, v$fp2))
    halves <- rbind(halves, dp_halves(ratio(v$cur2_half[, 1], v$fp2_half[, 1]),
                                      ratio(v$cur2_half[, 2], v$fp2_half[, 2]), mask))
    rownames(halves) <- c("current", "normalized_current")
  }
  if (!is.null(v$pow)) {
    pratio <- function(a, b) ifelse(b > 0, a / b, NA_real_)
    values <- cbind(values, power = v$pow)
    halves <- rbind(halves, power = dp_halves(v$pow_half[, 1], v$pow_half[, 2], mask))
    if (normalize) {
      values <- cbind(values, normalized_power = pratio(v$pow, v$fpow))
      halves <- rbind(halves, normalized_power = dp_halves(
        pratio(v$pow_half[, 1], v$fpow_half[, 1]),
        pratio(v$pow_half[, 2], v$fpow_half[, 2]), mask))
    }
  }
  list(values = values, halves = halves)
}

#' Agreement Between the Odd- and Even-Draw Estimates of a Map
#' @noRd
dp_halves <- function(h1, h2, mask) {
  ok <- mask & is.finite(h1) & is.finite(h2) & h1 > 0 & h2 > 0
  if (sum(ok) < 3) {
    return(data.frame(spearman = NA_real_, median_rel_diff = NA_real_))
  }
  data.frame(
    spearman = stats::cor(h1[ok], h2[ok], method = "spearman"),
    median_rel_diff = stats::median(abs(h1[ok] - h2[ok]) / ((h1[ok] + h2[ok]) / 2))
  )
}
