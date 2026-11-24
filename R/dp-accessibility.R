#' Accessibility of Targets From Each Cell
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps how much of its targets each cell can reach, as area: the habitat
#' within `radius` (`source_strength`), counted by how easily it is reached
#' across the resistance surface; or, with a `destination`, the same between
#' two distributions in both directions. Where [dp_omni()] and [dp_flux()]
#' map where movement passes, this maps how connected each place is. Every
#' cell gets a value, not only habitat, so it also shows how connected a
#' site would be there.
#'
#' @details
#' A cell's targets are the cells of its connected component within
#' `radius` and beyond its own site (see "Sites"), weighted by target
#' strength \eqn{t}. Three layers describe them:
#' \describe{
#'   \item{`accessible_area`}{The targets in reach, counted by how easily
#'     they are reached: \eqn{\mathrm{target\_area}_i \, C_i / C^*}, where
#'     \eqn{C_i} is `conductance` and \eqn{C^*} is the conductance a site
#'     would have in continuous habitat (every cell a target, of resistance
#'     `reference_resistance`) at the same `radius` and `site_radius`.
#'     Targets as easy to reach as in continuous habitat count in full, and
#'     harder ones proportionally less; targets close to the site, or
#'     through resistance below the reference, can count for more. It
#'     responds to the amount of targets, their arrangement and the
#'     resistance surface together.}
#'   \item{`target_area`}{The targets in reach as area, each cell's area
#'     weighted by its target strength: \eqn{\sum_{j \notin S_i} t_j a_j
#'     k(d_{ij})}, with \eqn{S_i} the cell's site, \eqn{a_j} the cell's area
#'     and \eqn{k} 1 within `radius` and 0 otherwise. For a 0-1 suitability
#'     it is the area of suitable habitat in reach; for strengths above 1 it
#'     is an area-equivalent, and can exceed the area in reach. It is exact,
#'     and ignores resistance.}
#'   \item{`conductance`}{The effective conductance from the site to its
#'     targets as a set: one over the effective resistance when one unit of
#'     current leaves the site and is withdrawn across its targets in
#'     proportion to their strength. Many targets in reach act like
#'     parallel paths and raise it. Its inverse is the injection of
#'     [dp_flux()] with the one site as the origin. It doesn't respond to
#'     how much target there is: thinning every target to a tenth of its
#'     strength leaves it unchanged, which is what `accessible_area` adds.}
#' }
#'
#' Areas are in square kilometres where the grid's coordinate reference
#' system gives cell areas (on lon/lat grids, per row, on a sphere), and in
#' cells otherwise; the `"area_units"` attribute says which. Cells without
#' targets in reach (none within `radius` and beyond their site, in the same
#' component) score 0 on all three layers. These include cells of pieces of
#' the circuit not much wider than a site, such as small islands, whose site
#' holds the whole piece.
#'
#' With a `destination`, each cell is scored in both directions, with
#' `origin_` and `destination_` prefixes on the layers. The `origin_`
#' layers take the cell as an origin, with the destination
#' (`destination`) as its targets: how well could movement from here reach
#' the destination? The `destination_` layers take the cell as a
#' destination, with the origin (`source_strength`) as its targets: how
#' reachable is this place from the origin? For present and future habitat,
#' the first asks which populations can track their habitat, the second
#' which future habitat can be colonised. Effective resistance is
#' symmetric, so the two differ only in their targets.
#'
#' ## Sites
#' Each cell stands for a site: the cells within `site_radius` of it,
#' across which the current is spread evenly. Targets are sites too, so
#' conductances are between the sites around cells. A site is never its own
#' target: a cell's targets are the habitat beyond its site, so `radius`
#' must reach beyond `site_radius`. Choose `site_radius` for the area a
#' population or site occupies. It has no default, because every layer
#' depends on it: give it in km, like `radius`, to compare grids of
#' different resolution.
#'
#' Sites matter because on a grid the effective resistance from a single
#' cell grows only with the log of distance, so most of it is in the first
#' few rings of links around the cell. A single cell's value is then
#' dominated by its own contact resistance, the resistance of its own links
#' in parallel, and maps the cell's own resistance more than its place in
#' the landscape. A site at least 2 cells in radius keeps that local term
#' from dominating, as Circuitscape's focal regions do.
#'
#' With `site_radius = 0`, each site is its single cell, and its own
#' resistance is part of its value: the reading for a single point of
#' interest. With `contact = TRUE`, the result includes the `contact` layer,
#' each cell's contact conductance (its own links in parallel, exact), an
#' upper bound on the single-cell `conductance`.
#'
#' ## The continuous-habitat reference
#' \eqn{C^*} is solved exactly, once per kernel, on a uniform grid wide
#' enough that its edges don't matter, and is inversely proportional to
#' `reference_resistance`: set that to the resistance of good habitat. On
#' lon/lat grids with `radius_units = "km"`, the kernel varies by row, and
#' so does \eqn{C^*}; rows within reach of the top or bottom of the grid use
#' the nearest row whose kernel fits, so that there, as at other edges, the
#' grid's edge lowers accessible area rather than the reference. With
#' `radius = Inf`, continuous habitat has no finite reference, and the
#' result has no `accessible_area` layer.
#'
#' A larger `radius` raises `target_area` everywhere and `accessible_area`
#' almost everywhere, but not at every cell: the current is withdrawn from
#' the targets in fixed proportions, so where widening the radius adds
#' mostly hard-to-reach targets, it lowers the conductance to all of them,
#' and accessible area can fall.
#'
#' ## Method
#' Each draw injects a random-sign dipole across every link of the circuit,
#' scaled by the square root of the link's conductance, and solves the
#' circuit once. For the solution \eqn{y}, \eqn{(y_i - y_j)^2} is then an
#' unbiased estimate of the effective resistance between \eqn{i} and
#' \eqn{j} for every pair at once, and the resistance to the targets comes
#' from sums of \eqn{y} over each cell's targets, after averaging \eqn{y}
#' over each site. Its mean over draws estimates the resistance without
#' bias; `conductance` and `accessible_area` invert it, corrected for the
#' bias of inverting a noisy estimate. `target_area` and all window sums use
#' per-row running sums, at a cost linear in the radius.
#'
#' Flow potential has no direct analogue here. With `normalize`, the same
#' draws on the uniform circuit (conductance 1 on the same cells, with the
#' same targets) give the conductance for geometry alone, and
#' `normalized_conductance` divides by it: the conductance of a uniform
#' landscape of the same shape that would give the same value, in the
#' units of the input's conductance. A value of 0.5 means the cell is as
#' connected as it would be if every cell had resistance 2. Below the
#' landscape's typical conductance, the cell is isolated by its
#' resistances; above, by geometry (distance, edges, few targets) more than
#' by resistance. Unlike `accessible_area`, it compares each cell with its
#' own geometry, so it doesn't respond to the amount of targets either.
#'
#' ## Accuracy
#' Each draw's resistance estimate is a squared Gaussian-like quantity, so
#' the relative standard error of `conductance` and `accessible_area` is
#' about \eqn{\sqrt{2 / \mathrm{n\_draws}}} at any grid size: about 18% at
#' the default 64 draws, and 10% at 200. Both circuits see the same draws,
#' so on landscapes of modest contrast the noise of `normalized_conductance`
#' largely cancels, but where resistance varies by orders of magnitude it
#' doesn't. With `se = TRUE`, the result includes each estimated layer's
#' per-cell standard error; the `"relative_se"` attribute gives each
#' estimated layer's median relative standard error either way.
#'
#' Reproducibility, performance and progress are as for [dp_omni()]: one
#' factorization (two with `normalize`), then about `n_draws` solves, plus a
#' small factorization and one solve per kernel for the reference.
#'
#' @inheritParams dp_omni
#' @param site_radius Number. The radius of the site each cell stands for
#'   (see "Sites"), in `radius_units`. `0` is the cell alone. Required.
#' @param source_strength Optional [terra::SpatRaster] or file path on the
#'   same grid: target strength, e.g. habitat suitability. If `NULL`
#'   (default), the conductance surface is used, as in [dp_omni()]. With a
#'   `destination`, this is the origin strength: the targets of the
#'   `destination_` layers.
#' @param destination Optional [terra::SpatRaster] or file path on the same
#'   grid: destination strength, the targets of the `origin_` layers.
#'   Default `NULL`: one set of targets.
#' @param reference_resistance Positive number. The resistance of the
#'   continuous habitat that `accessible_area` compares with, in the units of
#'   the input's resistance (also when `resistance_is = "conductances"`).
#'   Default `1`.
#' @param normalize Logical. Also return `normalized_conductance` (see
#'   "Method"). Default `TRUE`.
#' @param n_draws Integer. Number of draws (solves). Default `64`.
#' @param se Logical. Also return each estimated layer's per-cell standard
#'   error, as layers with an `_se` suffix. Default `FALSE`.
#' @param contact Logical. Also return each cell's contact conductance, the
#'   conductance of its own links in parallel, as the `contact` layer (see
#'   "Sites"). Default `FALSE`.
#'
#' @return A [terra::SpatRaster] with layers `accessible_area` (unless
#'   `radius` is `Inf`), `target_area` and `conductance`; with `normalize`,
#'   `normalized_conductance`; and with `se`, an `_se` layer for each but
#'   `target_area`, which is exact. With a `destination`, this set of layers
#'   twice, prefixed `origin_` and `destination_`. With `contact`, a last
#'   layer `contact`. Cells off the circuit are NA, as is
#'   `normalized_conductance` where a cell has no targets. Attributes:
#'   `"area_units"` (`"km2"` or `"cells"`), `"relative_se"` (each estimated
#'   layer's median relative standard error over the cells with targets)
#'   and `"seed"`.
#'
#' @seealso [dp_omni()], [dp_flux()], [dp_circuit()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' result <- dp_accessibility(resistance, radius = 15, site_radius = 2, seed = 1)
#' terra::plot(result)
#' attr(result, "area_units")
#' attr(result, "relative_se")
#'
#' # Between two distributions, in both directions
#' origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
#' between <- dp_accessibility(resistance, radius = 45, site_radius = 2,
#'                             source_strength = origin, destination = destination,
#'                             normalize = FALSE, seed = 1)
#' terra::plot(between)
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_accessibility <- function(resistance, radius, site_radius, source_strength = NULL,
                             destination = NULL, source_threshold = 0.01,
                             radius_units = c("pixels", "km"),
                             resistance_is = "resistances", reference_resistance = 1,
                             normalize = TRUE, n_draws = 64, seed = NULL, se = FALSE,
                             contact = FALSE, progress = TRUE) {
  if (missing(site_radius)) {
    stop("`site_radius` is required: the radius, in `radius_units`, of the site ",
         "each cell stands for, such as the area a population occupies. ",
         "A site at least 2 cells in radius keeps a cell's own links from ",
         "dominating its value; give it in km to compare resolutions.", call. = FALSE)
  }
  radius_units <- match.arg(radius_units)
  n_draws <- dp_count(n_draws, "n_draws", min = 2)
  seed <- dp_seed(seed)
  normalize <- isTRUE(normalize)
  se <- isTRUE(se)
  contact <- isTRUE(contact)
  dp_check_site_radius(site_radius)
  if (!is.numeric(reference_resistance) || length(reference_resistance) != 1 ||
      is.na(reference_resistance) || reference_resistance <= 0 ||
      !is.finite(reference_resistance)) {
    stop("`reference_resistance` must be a positive number.", call. = FALSE)
  }

  input <- dp_circuit_input(resistance, resistance_is)
  kernel_finite <- !(is.numeric(radius) && length(radius) == 1 && isTRUE(is.infinite(radius)))
  p <- dp_progressor(progress, dp_factor_steps(input, normalize) +
                       dp_draw_steps(input, n_draws, 1 + normalize) + kernel_finite)
  circuit <- dp_as_circuit(input, uniform = normalize, p = p)
  kernel <- dp_kernel(circuit$env$template, radius, radius_units)
  site <- dp_site_kernel(circuit$env$template, site_radius, radius_units)
  if (!dp_kernel_beyond(kernel, site)) {
    stop("`radius` must reach beyond `site_radius`: a cell's targets are the ",
         "cells within `radius` beyond its own site.", call. = FALSE)
  }
  w <- dp_weights(circuit, source_strength, source_threshold, "source_strength")
  targets <- if (is.null(destination)) {
    list(w)
  } else {
    list(origin_ = dp_weights(circuit, destination, source_threshold, "destination"),
         destination_ = w)
  }

  env <- circuit$env
  ids <- c(env$id, if (normalize) env$uniform_id)
  res <- dp_call("isolation", as.integer(ids), do.call(cbind, targets), kernel$dr0,
                 kernel$hw, kernel$rowmap, site$dr0, site$hw, site$rowmap, seed,
                 n_draws, 0L, dp_julia_progress(p))
  if (all(vapply(res$reach, function(a) !any(a > 0), TRUE))) {
    stop("No cell has a target within `radius` in the same part of the circuit.",
         call. = FALSE)
  }

  cell_area <- dp_cell_area(env$template, env$cells)
  area <- dp_call("target_sums", env$id, do.call(cbind, targets) * cell_area$area,
                  kernel$dr0, kernel$hw, kernel$rowmap, site$dr0, site$hw, site$rowmap)
  reference <- NULL
  if (kernel_finite) {
    ref <- dp_call("continuous_reference", env$id, kernel$dr0, kernel$hw, kernel$rowmap,
                   site$dr0, site$hw, site$rowmap, dp_julia_progress(p))
    # Conductance of continuous habitat of the reference resistance
    reference <- 1 / (ref$resistance * reference_resistance)
  }

  prefixes <- if (is.null(destination)) "" else names(targets)
  layers <- lapply(seq_along(prefixes), function(k) {
    m <- dp_accessibility_layers(res$dist[[k]], res$reach[[k]], area[[k]], reference,
                                 n_draws, normalize, se)
    colnames(m) <- paste0(prefixes[k], colnames(m))
    m
  })
  values <- do.call(cbind, layers)
  if (contact) {
    gsum <- 1 / res$contact
    values <- cbind(values, contact = ifelse(is.finite(gsum), gsum, NA_real_))
  }
  out <- dp_to_raster(circuit, values, colnames(values))
  attr(out, "area_units") <- cell_area$units
  attr(out, "relative_se") <- unlist(lapply(seq_along(layers), function(k) {
    x <- attr(layers[[k]], "relative_se")
    stats::setNames(x, paste0(prefixes[k], names(x)))
  }))
  attr(out, "seed") <- seed
  out
}

#' Layers From Per-Cell Sums Over Draws
#'
#' @param sums Nodes x 5 matrix from Julia's `isolation()`: sums over draws
#'   of x, x^2, u, u^2 and x u, with x the resistance estimate and u the same
#'   on the uniform circuit.
#' @param reach Summed target weight within reach; cells with none score 0
#'   (NA for the normalized layer).
#' @param area Target area per node, from Julia's `target_sums()`.
#' @param reference `NULL` (no finite radius), or the conductance of
#'   continuous habitat per node.
#' @return A matrix of layers: `accessible_area` (with a reference),
#'   `target_area`, `conductance`, `normalized_conductance` (with
#'   `normalize`), then with `se` the standard errors of all but
#'   `target_area`.
#' @noRd
dp_accessibility_layers <- function(sums, reach, area, reference, n, normalize, se) {
  has <- reach > 0
  # Inverting the mean of the draws biases 1 / R up by about (SE / R)^2
  invert <- function(r, rel) ifelse(has & r > 0, 1 / r / (1 + rel^2), NA_real_)
  R <- sums[, 1] / n
  rel <- sqrt(pmax(sums[, 2] - n * R^2, 0) / (n - 1) / n) / R
  cond <- invert(R, rel)
  est <- list()
  err <- list()
  if (!is.null(reference)) {
    est$accessible_area <- area * cond / reference
    err$accessible_area <- est$accessible_area * rel
  }
  est$target_area <- area
  est$conductance <- cond
  err$conductance <- cond * rel
  if (normalize) {
    mu <- sums[, 3] / n
    r <- ifelse(mu > 0, sums[, 1] / sums[, 3], NA_real_)
    # Residuals x - r u sum to zero; their spread gives the ratio's error
    z2 <- sums[, 2] - 2 * r * sums[, 5] + r^2 * sums[, 4]
    rel_n <- sqrt(pmax(z2, 0) / (n - 1) / n) / mu / r
    est$normalized_conductance <- invert(r, rel_n)
    err$normalized_conductance <- est$normalized_conductance * rel_n
  }
  relative <- vapply(names(err), function(k) {
    ok <- has & is.finite(est[[k]]) & est[[k]] > 0
    stats::median(err[[k]][ok] / est[[k]][ok])
  }, 0)
  # No targets in reach: no access (the normalized layer is 0 / 0)
  for (k in setdiff(names(est), "normalized_conductance")) est[[k]][!has] <- 0
  for (k in setdiff(names(err), "normalized_conductance")) err[[k]][!has] <- 0
  values <- do.call(cbind, est)
  if (se) {
    errs <- do.call(cbind, err)
    colnames(errs) <- paste0(names(err), "_se")
    values <- cbind(values, errs)
  }
  attr(values, "relative_se") <- relative
  values
}

#' Area of Each Node's Cell
#'
#' km^2 where the grid's coordinate reference system gives areas: on
#' lon/lat grids, per row, on the same sphere as the km kernels; on
#' projected grids, the cell's width times height in the CRS's linear unit.
#' Otherwise 1 per cell, in units of cells.
#' @return A list: `area`, per node, and `units`, `"km2"` or `"cells"`.
#' @noRd
dp_cell_area <- function(template, cells) {
  if (isTRUE(suppressWarnings(terra::is.lonlat(template)))) {
    rows <- terra::rowFromCell(template, cells)
    lat <- terra::yFromRow(template, rows) * pi / 180
    half <- terra::yres(template) / 2 * pi / 180
    dlon <- terra::xres(template) * pi / 180
    area <- earth_radius_km()^2 * dlon * (sin(pmin(lat + half, pi / 2)) - sin(pmax(lat - half, -pi / 2)))
    return(list(area = area, units = "km2"))
  }
  unit <- suppressWarnings(terra::linearUnits(template))
  if (!is.na(unit) && unit > 0) {
    km <- unit / 1000
    return(list(area = rep(terra::xres(template) * km * terra::yres(template) * km, length(cells)),
                units = "km2"))
  }
  list(area = rep(1, length(cells)), units = "cells")
}

#' Does a Kernel Reach Beyond the Site, on Some Grid Row?
#'
#' Both kernels are centred runs of columns on each row offset, so the
#' kernel reaches beyond the site where, on some row offset, its run is
#' wider than the site's (or the site has none).
#' @noRd
dp_kernel_beyond <- function(kernel, site) {
  if (length(kernel$hw) == 0 || length(site$hw) == 0) return(TRUE)
  rows <- which(!duplicated(cbind(kernel$rowmap, site$rowmap)))
  for (r in rows) {
    hk <- kernel$hw[, kernel$rowmap[r]]
    dr <- kernel$dr0 + seq_along(hk) - 1
    d <- dr - site$dr0 + 1
    hs <- rep(-1L, length(hk))
    ok <- d >= 1 & d <= nrow(site$hw)
    hs[ok] <- site$hw[d[ok], site$rowmap[r]]
    if (any(hk > hs)) return(TRUE)
  }
  FALSE
}

#' Check `site_radius`: a finite number of at least 0
#' @noRd
dp_check_site_radius <- function(site_radius) {
  if (!is.numeric(site_radius) || length(site_radius) != 1 || is.na(site_radius) ||
      site_radius < 0 || !is.finite(site_radius)) {
    stop("`site_radius` must be a finite number of at least 0.", call. = FALSE)
  }
  invisible()
}

#' The Site Kernel: Cells Within `site_radius`
#'
#' A radius under one cell is the cell alone, passed to Julia as an empty kernel (no
#' averaging).
#' @noRd
dp_site_kernel <- function(template, site_radius, units) {
  k <- if (units == "pixels") {
    dp_kernel_pixels(site_radius, terra::nrow(template))
  } else if (isTRUE(suppressWarnings(terra::is.lonlat(template)))) {
    dp_kernel_lonlat(template, site_radius)
  } else {
    dp_kernel_projected(template, site_radius)
  }
  # Only the cell itself on every row: no averaging
  own <- 1 - k$dr0
  alone <- all(k$hw[-own, , drop = FALSE] < 0) && all(k$hw[own, ] <= 0)
  if (site_radius == 0 || alone) dp_kernel_none() else k
}
