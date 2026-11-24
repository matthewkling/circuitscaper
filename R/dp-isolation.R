#' Isolation of Each Cell From Its Targets
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps how well connected each cell is to its targets, as effective
#' resistance: to the habitat within `radius` (`source_strength`), or, with a
#' `destination`, between the two distributions in both directions. Where
#' [dp_omni()] and [dp_flux()] map where movement passes, this maps how
#' isolated each place is. Every cell with targets in reach gets a value,
#' not only habitat, so it also shows how connected a site would be there.
#'
#' @details
#' A cell's targets are the cells of its connected component within
#' `radius` and beyond its own site (see "Sites"; for single cells, the
#' other cells), each weighted by its share \eqn{q_j} of the cell's target
#' strength in reach, \eqn{A_i = \sum_{j \notin S_i} t_j k(d_{ij})}, where
#' \eqn{t} is the target strength, \eqn{S_i} is the cell's site, and
#' \eqn{k} is 1 within `radius` and 0 otherwise. With \eqn{R_{ij}} the effective resistance between the sites
#' around cells \eqn{i} and \eqn{j} (see "Sites") on the whole circuit, two
#' layers summarise the targets:
#' \describe{
#'   \item{`resistance`}{Resistance to the target distribution: the
#'     effective resistance when one unit of current leaves the site and
#'     is withdrawn across its targets in proportion to \eqn{q}. Many
#'     targets in reach act like parallel paths and lower it, so it measures
#'     how well the site is connected to its targets as a set. It is the
#'     injection of [dp_flux()] with the one site as the origin.}
#'   \item{`mean_resistance`}{Mean effective resistance to the targets,
#'     \eqn{\sum_j q_j R_{ij}}: the difficulty of reaching a typical target.
#'     It is at least `resistance`, by the spread of the targets among
#'     themselves, and the targets that are hardest to reach weigh most in
#'     it. With `site_radius = 0`, summed over cells with weights
#'     \eqn{w_i A_i}, it gives the total effective resistance over the pairs
#'     of [dp_omni()].}
#' }
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
#' Cells without targets in reach (none within `radius` and beyond their
#' site, in the same component) are NA. These include cells of pieces of
#' the circuit not much wider than a site, such as small islands, whose
#' site holds the whole piece.
#'
#' ## Sites
#' Each cell stands for a site: the cells within `site_radius` of it (2
#' pixels by default), across which the current is spread evenly. Targets
#' are sites too, so \eqn{R_{ij}} above is the effective resistance between
#' the sites around \eqn{i} and \eqn{j}. A site is never its own target:
#' a cell's targets are the habitat beyond its site, as a single cell's are
#' the other cells, so `radius` must reach beyond `site_radius`. This matters because on a grid,
#' the effective resistance from a single cell grows only with the log of
#' distance, so most of it is in the first few rings of links around the
#' cell. A single cell's value is then dominated by its own contact
#' resistance, the resistance of its own links in parallel, and maps the
#' cell's own resistance more than its place in the landscape. Spreading the
#' current over a site keeps that local term from dominating, as
#' Circuitscape's focal regions do. Choose `site_radius` for the area a
#' population or site occupies; values depend on it, so compare runs at the
#' same site radius.
#'
#' With `site_radius = 0`, each site is its single cell, and its own
#' resistance is part of its isolation: the reading for a single point of
#' interest. With `contact = TRUE`, the result includes the `contact` layer,
#' each cell's contact resistance (exact, not estimated), which is a lower
#' bound on the single-cell `resistance`. Subtracting it leaves the
#' resistance beyond the cell's own links, but the subtraction doesn't
#' remove any noise, so where contact is most of the value (high-resistance
#' cells), the remainder is very noisy.
#'
#' ## Coverage
#' `resistance` responds to where the targets are, not to how much of them
#' there is: \eqn{q} is a share, so thinning every target to a tenth of its
#' strength leaves it unchanged. With `coverage = TRUE`, two layers compare
#' each cell with ideal continuous habitat: every cell a target of strength
#' 1 and of resistance `reference_resistance`, at the same `radius` and
#' `site_radius`, and with no edges.
#' \describe{
#'   \item{`coverage`}{Target strength in reach as a share of the ideal's,
#'     \eqn{A_i / A^*}, where \eqn{A^*} is the number of cells within
#'     `radius` and beyond the site: the mean target strength over the ring
#'     between the site and the radius, with cells that are NA, off the
#'     grid or in another component counting as zero. It is exact, and in
#'     units of target strength, so it runs from 0 to 1 for strengths that
#'     do (such as suitability). It ignores resistance.}
#'   \item{`effective_coverage`}{Coverage discounted by how much harder
#'     the targets are to reach than in ideal habitat,
#'     \eqn{(A_i / A^*) (R^* / R_i)}, where \eqn{R_i} is `resistance` and
#'     \eqn{R^*} is its ideal value: target strength in reach per unit
#'     resistance, relative to ideal habitat. 1 is as connected as ideal
#'     habitat; it responds to the amount of targets, their arrangement
#'     and the resistance surface together. Its relative noise is that of
#'     `resistance`, and it is corrected for the bias of inverting a noisy
#'     estimate.}
#' }
#'
#' \eqn{R^*} is solved exactly, once per kernel, on a uniform grid wide
#' enough that its edges don't matter. It is proportional to
#' `reference_resistance`, so effective coverage depends on the units of
#' resistance: set `reference_resistance` to the resistance of good
#' habitat, so that 1 means as connected as continuous good habitat. On
#' lon/lat grids with `radius_units = "km"`, cells narrow towards the
#' poles, so the kernel, and with it \eqn{A^*} and \eqn{R^*}, vary by row.
#' Rows within reach of the top or bottom of the grid use the nearest row
#' whose kernel fits, so that there, as at other edges, the grid's edge
#' lowers coverage. Coverage needs a finite `radius`.
#'
#' ## Method
#' Each draw injects a random-sign dipole across every link of the circuit,
#' scaled by the square root of the link's conductance, and solves the
#' circuit once. For the solution \eqn{y}, \eqn{(y_i - y_j)^2} is then an
#' unbiased estimate of \eqn{R_{ij}} for every pair at once, and both layers
#' come from sums of \eqn{y} and \eqn{y^2} over each cell's targets, after
#' averaging \eqn{y} over each site. Their mean over draws estimates each
#' layer without bias.
#'
#' Flow potential has no direct analogue here. With `normalize`, the same
#' draws on the uniform circuit (conductance 1 on the same cells) give the
#' same quantities for geometry alone, and the normalized layers divide by
#' them: the resistance of a unit-resistance landscape of the same shape
#' that would give the same isolation, so in the units of the input's
#' resistance. A normalized value of 2 means the cell is as isolated as it
#' would be if every cell had resistance 2. Above the landscape's typical
#' resistance, the cell is isolated by its resistances; below, by geometry
#' (distance, edges, few targets) more than by resistance.
#'
#' ## Accuracy
#' Each draw's estimate of `resistance` is a squared Gaussian-like quantity,
#' so its relative standard error is about \eqn{\sqrt{2 / \mathrm{n\_draws}}}
#' at any grid size: about 18% at the default 64 draws, and 10% at 200.
#' `mean_resistance` averages over targets and is usually less noisy. Both
#' circuits see the same draws, so on landscapes of modest contrast the
#' noise of the normalized layers largely cancels, but where resistance
#' varies by orders of magnitude it doesn't. With `se = TRUE`, the result includes each layer's per-cell
#' standard error, from the spread of the draws; the `"relative_se"`
#' attribute gives each layer's median relative standard error either way.
#'
#' Reproducibility, performance and progress are as for [dp_omni()]: one
#' factorization (two with `normalize`), then about `n_draws` solves.
#' Coverage adds a small factorization and one solve per kernel.
#'
#' @inheritParams dp_omni
#' @param source_strength Optional [terra::SpatRaster] or file path on the
#'   same grid: target strength, e.g. habitat suitability. If `NULL`
#'   (default), the conductance surface is used, as in [dp_omni()]. With a
#'   `destination`, this is the origin strength: the targets of the
#'   `destination_` layers.
#' @param destination Optional [terra::SpatRaster] or file path on the same
#'   grid: destination strength, the targets of the `origin_` layers.
#'   Default `NULL`: one set of targets.
#' @param site_radius Numeric or `NULL`. The radius of the site each cell
#'   stands for (see "Sites"), in `radius_units`. `0` is the cell alone.
#'   Default `NULL`: 2 pixels, whatever `radius_units`.
#' @param n_draws Integer. Number of draws (solves). Default `64`.
#' @param se Logical. Also return each layer's per-cell standard error, as
#'   layers with an `_se` suffix. Default `FALSE`.
#' @param coverage Logical. Also return the `coverage` and
#'   `effective_coverage` layers, which compare each cell with ideal
#'   continuous habitat (see "Coverage"). Default `FALSE`.
#' @param reference_resistance Positive number. The resistance of the ideal
#'   habitat for `effective_coverage`, in the units of the input's
#'   resistance (also when `resistance_is = "conductances"`). Default `1`.
#' @param contact Logical. Also return each cell's contact resistance, the
#'   resistance of its own links in parallel, as the `contact` layer (see
#'   "Sites"). Default `FALSE`.
#'
#' @return A [terra::SpatRaster] with layers `resistance` and
#'   `mean_resistance`; with `normalize`, `normalized_resistance` and
#'   `normalized_mean_resistance`; with `coverage`, `coverage` and
#'   `effective_coverage`; and with `se`, an `_se` layer for each but
#'   `coverage`, which is exact.
#'   With a `destination`, this set of layers twice, prefixed `origin_` and
#'   `destination_`. With `contact`, a last layer `contact`. Attributes:
#'   `"relative_se"`, each layer's median relative standard error over the
#'   cells with values, and `"seed"`.
#'
#' @seealso [dp_omni()], [dp_flux()], [dp_circuit()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' result <- dp_isolation(resistance, radius = 15, seed = 1)
#' terra::plot(result)
#' attr(result, "relative_se")
#'
#' # Compared with ideal continuous habitat of resistance 1
#' covered <- dp_isolation(resistance, radius = 15, normalize = FALSE,
#'                         coverage = TRUE, seed = 1)
#' terra::plot(covered[[c("coverage", "effective_coverage")]])
#'
#' # Isolation between two distributions, in both directions
#' origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
#' between <- dp_isolation(resistance, radius = 45, source_strength = origin,
#'                         destination = destination, normalize = FALSE, seed = 1)
#' terra::plot(between)
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_isolation <- function(resistance, radius, source_strength = NULL,
                         destination = NULL, site_radius = NULL, source_threshold = 0.01,
                         radius_units = c("pixels", "km"),
                         resistance_is = "resistances", normalize = TRUE,
                         n_draws = 64, seed = NULL, se = FALSE, coverage = FALSE,
                         reference_resistance = 1, contact = FALSE,
                         progress = TRUE) {
  radius_units <- match.arg(radius_units)
  n_draws <- dp_count(n_draws, "n_draws", min = 2)
  seed <- dp_seed(seed)
  normalize <- isTRUE(normalize)
  se <- isTRUE(se)
  contact <- isTRUE(contact)
  coverage <- isTRUE(coverage)
  dp_check_site_radius(site_radius)
  if (coverage) {
    if (!is.numeric(reference_resistance) || length(reference_resistance) != 1 ||
        is.na(reference_resistance) || reference_resistance <= 0 ||
        !is.finite(reference_resistance)) {
      stop("`reference_resistance` must be a positive number.", call. = FALSE)
    }
    if (is.numeric(radius) && length(radius) == 1 && isTRUE(is.infinite(radius))) {
      stop("`coverage` needs a finite `radius`: with no distance limit there is ",
           "no ideal neighbourhood to compare with.", call. = FALSE)
    }
  }

  input <- dp_circuit_input(resistance, resistance_is)
  p <- dp_progressor(progress, dp_factor_steps(input, normalize) +
                       dp_draw_steps(input, n_draws, 1 + normalize) + coverage)
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

  ideal <- if (coverage) {
    ref <- dp_call("ideal_reference", env$id, kernel$dr0, kernel$hw, kernel$rowmap,
                   site$dr0, site$hw, site$rowmap, dp_julia_progress(p))
    list(reach = ref$reach, resistance = ref$resistance * reference_resistance)
  }

  prefixes <- if (is.null(destination)) "" else names(targets)
  layers <- lapply(seq_along(prefixes), function(k) {
    m <- dp_isolation_layers(list(resistance = res$dist[[k]],
                                  mean_resistance = res$mean[[k]]),
                             res$reach[[k]], n_draws, normalize, se, ideal)
    colnames(m) <- paste0(prefixes[k], colnames(m))
    m
  })
  values <- do.call(cbind, layers)
  if (contact) {
    values <- cbind(values, contact = ifelse(is.finite(res$contact), res$contact, NA_real_))
  }
  out <- dp_to_raster(circuit, values, colnames(values))
  attr(out, "relative_se") <- dp_isolation_relative_se(layers, prefixes, normalize)
  attr(out, "seed") <- seed
  out
}

#' Layers From Per-Cell Sums Over Draws
#'
#' @param sums Named list of nodes x 5 matrices from Julia's `isolation()`:
#'   sums over draws of x, x^2, u, u^2 and x u, with u the same statistic on
#'   the uniform circuit.
#' @param reach Summed target weight within reach; cells with none are NA.
#' @param ideal `NULL`, or a list of per-node `reach` and `resistance` in
#'   ideal habitat (Julia's `ideal_reference()`, the resistance scaled to
#'   the reference resistance), for the coverage layers.
#' @return A matrix of layers: each statistic, then with `normalize` each
#'   normalized statistic, then with `ideal` the coverage layers, then with
#'   `se` the standard errors of all but `coverage` (which is exact). The
#'   normalized standard error is the delta method's for a ratio of means.
#' @noRd
dp_isolation_layers <- function(sums, reach, n, normalize, se, ideal = NULL) {
  none <- !(reach > 0)
  est <- list()
  err <- list()
  for (name in names(sums)) {
    s <- sums[[name]]
    m <- s[, 1] / n
    est[[name]] <- m
    err[[name]] <- sqrt(pmax(s[, 2] - n * m^2, 0) / (n - 1) / n)
  }
  if (normalize) {
    for (name in names(sums)) {
      s <- sums[[name]]
      mu <- s[, 3] / n
      r <- ifelse(mu > 0, s[, 1] / s[, 3], NA_real_)
      # Residuals x - r u sum to zero; their spread gives the ratio's error
      z2 <- s[, 2] - 2 * r * s[, 5] + r^2 * s[, 4]
      key <- paste0("normalized_", name)
      est[[key]] <- r
      err[[key]] <- sqrt(pmax(z2, 0) / (n - 1) / n) / mu
    }
  }
  if (!is.null(ideal)) {
    cover <- reach / ideal$reach
    # 1 / R from the mean of draws is biased up by about (SE / R)^2
    R <- est$resistance
    rel <- err$resistance / R
    eff <- ifelse(R > 0, cover * ideal$resistance / R / (1 + rel^2), NA_real_)
    est$coverage <- cover
    est$effective_coverage <- eff
    err$effective_coverage <- eff * rel
  }
  values <- do.call(cbind, est)
  if (se) {
    errs <- do.call(cbind, err)
    colnames(errs) <- paste0(names(err), "_se")
    values <- cbind(values, errs)
  }
  attr(values, "relative_se") <- vapply(names(err), function(k) {
    ok <- !none & is.finite(est[[k]]) & est[[k]] > 0
    stats::median(err[[k]][ok] / est[[k]][ok])
  }, 0)
  values[none, ] <- NA_real_
  values
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

#' Check `site_radius`: `NULL`, or a finite number of at least 0
#' @noRd
dp_check_site_radius <- function(site_radius) {
  if (is.null(site_radius)) return(invisible())
  if (!is.numeric(site_radius) || length(site_radius) != 1 || is.na(site_radius) ||
      site_radius < 0 || !is.finite(site_radius)) {
    stop("`site_radius` must be a finite number of at least 0, or NULL.", call. = FALSE)
  }
  invisible()
}

#' The Site Kernel: Cells Within `site_radius`
#'
#' `NULL` is the default of 2 pixels, whatever `units`. A radius under one
#' cell is the cell alone, passed to Julia as an empty kernel (no
#' averaging).
#' @noRd
dp_site_kernel <- function(template, site_radius, units) {
  if (is.null(site_radius)) {
    site_radius <- 2
    units <- "pixels"
  }
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

dp_isolation_relative_se <- function(layers, prefixes, normalize) {
  unlist(lapply(seq_along(layers), function(k) {
    x <- attr(layers[[k]], "relative_se")
    stats::setNames(x, paste0(prefixes[k], names(x)))
  }))
}
