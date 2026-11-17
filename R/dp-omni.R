#' Omnidirectional Connectivity From Random Dipoles
#'
#' Maps omnidirectional connectivity among habitat, in the role of
#' [os_run()], with the random-dipole method: many random source-sink pairs
#' superposed on one factored circuit, which takes about `n_draws` solves
#' whatever the number of pairs.
#'
#' @details
#' For each link \eqn{e} of the circuit (see [dp_circuit()]), the method
#' estimates
#' \deqn{T_e = \sum_{i \ne j} w_i w_j k(d_{ij}) I_e(i,j)^2}
#' over ordered pairs of cells, where \eqn{w} is source strength, \eqn{k} is
#' 1 for cells within `radius` of each other and 0 otherwise, and
#' \eqn{I_e(i,j)} is the current through \eqn{e} when one unit flows from
#' \eqn{i} to \eqn{j} on the whole circuit. A cell's current is
#' \eqn{\sqrt{\frac{1}{2}\sum_{e \ni \mathrm{cell}} T_e}}. For a unit flow,
#' a link's squared current is the derivative of the pair's effective
#' resistance with respect to that link's resistance, so the map is the
#' sensitivity of habitat-weighted pairwise resistance to degrading each
#' cell.
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
#' @param resistance A [terra::SpatRaster] or file path: the resistance (or
#'   conductance) surface. Or a circuit from [dp_circuit()], to reuse its
#'   factorization.
#' @param radius Numeric. The dispersal radius: pairs of cells are counted
#'   if their centres are at most this far apart. In pixels by default (see
#'   `radius_units`). `Inf` counts all pairs.
#' @param source_strength Optional [terra::SpatRaster] or file path on the
#'   same grid: source strength, e.g. habitat suitability. If `NULL`
#'   (default), the conductance surface is used, as in [os_run()].
#' @param source_threshold Numeric. Cells with source strength below this
#'   are not sources. Default `0.01`.
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
#'
#' @return A [terra::SpatRaster] with layers `current`, and with
#'   `normalize`, `flow_potential` and `normalized_current`. Attributes:
#'   `"halves"`, a data frame comparing the estimates from odd and even
#'   draws on source cells (Spearman's \eqn{\rho} and the median relative
#'   difference), and `"seed"`.
#'
#' @seealso [dp_circuit()], [dp_pairwise()], [dp_pathways()], [os_run()]
#'
#' @examplesIf circuitscaper::cs_julia_available()
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' result <- dp_omni(resistance, radius = 15, seed = 1)
#' terra::plot(result)
#' attr(result, "halves")
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_omni <- function(resistance, radius, source_strength = NULL,
                    source_threshold = 0.01, radius_units = c("pixels", "km"),
                    resistance_is = "resistances", normalize = TRUE,
                    n_draws = 32, n_dipoles = 1e5, seed = NULL) {
  radius_units <- match.arg(radius_units)
  n_draws <- dp_count(n_draws, "n_draws", min = 2)
  n_dipoles <- dp_count(n_dipoles, "n_dipoles")
  seed <- dp_seed(seed)
  normalize <- isTRUE(normalize)

  circuit <- dp_as_circuit(resistance, resistance_is, uniform = normalize)
  kernel <- dp_kernel(circuit$env$template, radius, radius_units)
  w <- dp_weights(circuit, source_strength, source_threshold, "source_strength")
  dp_random_map(circuit, w, w, kernel, seed, n_draws, n_dipoles, normalize,
                mask = w > 0)
}


#' Map From Random-Sign Dipoles
#'
#' Runs the draws and turns the per-node sums into RMS cell values, scaled
#' by S / M, with the halves diagnostic over `mask`.
#' @noRd
dp_random_map <- function(circuit, w1, w2, kernel, seed, n_draws, n_dipoles,
                          normalize, mask) {
  res <- dp_random_dipoles(circuit, w1, w2, kernel, seed, n_draws, n_dipoles,
                           uniform = normalize)
  if (res$S <= 0) {
    stop("No pairs of source cells can be drawn: no two source cells are ",
         "within `radius` of each other in the same connected part of the ",
         "circuit.", call. = FALSE)
  }
  scale <- res$S / n_dipoles
  n_half <- c(ceiling(n_draws / 2), floor(n_draws / 2))
  rms <- function(cells) sqrt(0.5 * scale * rowSums(cells) / n_draws)
  half <- function(cells, p) 0.5 * scale * cells[, p] / n_half[p]

  cur <- rms(res$cells[[1]])
  halves <- dp_halves(sqrt(half(res$cells[[1]], 1)), sqrt(half(res$cells[[1]], 2)), mask)
  if (!normalize) {
    out <- dp_to_raster(circuit, cur, "current")
    rownames(halves) <- "current"
  } else {
    fp <- rms(res$cells[[2]])
    nc <- ifelse(fp > 0, cur / fp, NA_real_)
    out <- dp_to_raster(circuit, cbind(cur, fp, nc),
                        c("current", "flow_potential", "normalized_current"))
    h0 <- lapply(1:2, function(p) half(res$cells[[2]], p))
    h <- lapply(1:2, function(p) {
      ifelse(h0[[p]] > 0, sqrt(half(res$cells[[1]], p) / h0[[p]]), NA_real_)
    })
    halves <- rbind(halves, dp_halves(h[[1]], h[[2]], mask))
    rownames(halves) <- c("current", "normalized_current")
  }
  attr(out, "halves") <- halves
  attr(out, "seed") <- seed
  out
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
