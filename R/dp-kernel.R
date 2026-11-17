# Disk kernels for the dipole methods, as exact sets of cell offsets.
#
# A kernel is a list describing the offsets (dr, dc) from a source cell to
# the cells within reach: for row offset dr = dr0 + d - 1, column offsets
# -hw[d, k] .. hw[d, k] (none if hw < 0), where k = rowmap[row] lets the
# kernel vary with the source cell's grid row (on lon/lat grids, cells
# narrow towards the poles). An empty hw means no distance limit.

#' Kernel for a Radius
#' @param template SpatRaster giving the grid.
#' @param radius Numeric. `Inf` for no distance limit.
#' @param units `"pixels"` or `"km"`.
#' @noRd
dp_kernel <- function(template, radius, units = c("pixels", "km")) {
  units <- match.arg(units)
  if (!is.numeric(radius) || length(radius) != 1 || is.na(radius) || radius <= 0) {
    stop("`radius` must be a positive number (or Inf for no distance limit).",
         call. = FALSE)
  }
  if (is.infinite(radius)) return(dp_kernel_none())
  k <- if (units == "pixels") {
    dp_kernel_pixels(radius, terra::nrow(template))
  } else if (isTRUE(suppressWarnings(terra::is.lonlat(template)))) {
    dp_kernel_lonlat(template, radius)
  } else {
    dp_kernel_projected(template, radius)
  }
  # The kernel must reach some cell other than the source itself
  if (!any(k$hw > 0) && !any(k$hw[-(1 - k$dr0), , drop = FALSE] >= 0)) {
    stop("`radius` is smaller than a cell, so no pairs of cells are within ",
         "reach.", call. = FALSE)
  }
  k
}

#' No Distance Limit
#' @noRd
dp_kernel_none <- function() {
  list(dr0 = 0L, hw = matrix(0L, 0, 0), rowmap = integer(0))
}

#' Disk of `radius` Pixels: dr^2 + dc^2 <= radius^2
#'
#' The same kernel on every row, as in [os_run()].
#' @noRd
dp_kernel_pixels <- function(radius, nrow) {
  R <- floor(radius)
  dr <- -R:R
  list(dr0 = as.integer(-R), hw = matrix(isqrt_floor(radius^2 - dr^2), ncol = 1),
       rowmap = rep(1L, nrow))
}

#' Largest h With h^2 <= x, Robust to sqrt Rounding
#' @noRd
isqrt_floor <- function(x) {
  h <- floor(sqrt(pmax(x, 0)))
  h <- h + ((h + 1)^2 <= x)
  h <- h - (h^2 > x)
  as.integer(ifelse(x < 0, -1L, h))
}

#' Disk of `radius_km` on a Projected Grid
#'
#' Distances between cell centres in map units, converted to km with the
#' CRS's linear unit. Cells need not be square.
#' @noRd
dp_kernel_projected <- function(template, radius_km) {
  unit <- terra::linearUnits(template)
  if (is.na(unit) || unit <= 0) {
    stop("`radius_units = \"km\"` needs a coordinate reference system with ",
         "known units; set one with terra::crs(), or give `radius` in pixels.",
         call. = FALSE)
  }
  r <- radius_km * 1000 / unit
  rx <- terra::xres(template)
  ry <- terra::yres(template)
  R <- floor(r / ry)
  dr <- -R:R
  y2 <- (dr * ry)^2
  h <- floor(sqrt(pmax(r^2 - y2, 0)) / rx)
  h <- h + (((h + 1) * rx)^2 + y2 <= r^2)
  h <- h - ((h * rx)^2 + y2 > r^2)
  list(dr0 = as.integer(-R), hw = matrix(as.integer(h), ncol = 1),
       rowmap = rep(1L, terra::nrow(template)))
}

#' Great-Circle Distance (km) Between Points at Two Latitudes
#' @param phi1,phi2,dlambda Radians.
#' @noRd
haversine_km <- function(phi1, phi2, dlambda) {
  a <- sin((phi2 - phi1) / 2)^2 + cos(phi1) * cos(phi2) * sin(dlambda / 2)^2
  2 * earth_radius_km() * asin(sqrt(pmin(a, 1)))
}

earth_radius_km <- function() 6371.0088

#' Disk of `radius_km` on a Lon/Lat Grid
#'
#' Great-circle distance between cell centres on a sphere. Cells narrow
#' towards the poles, so the kernel varies by the source cell's row; each
#' source row gets its own kernel row. Offsets to rows outside the grid are
#' left out.
#' @noRd
dp_kernel_lonlat <- function(template, radius_km) {
  nr <- terra::nrow(template)
  nc <- terra::ncol(template)
  rx <- terra::xres(template) * pi / 180
  ry <- terra::yres(template) * pi / 180
  lat <- terra::yFromRow(template, seq_len(nr)) * pi / 180
  theta <- radius_km / earth_radius_km()
  R <- min(floor(theta / ry), nr - 1)
  dr <- -R:R
  hw <- matrix(-1L, length(dr), nr)
  for (r in seq_len(nr)) {
    r2 <- r + dr
    in_grid <- r2 >= 1 & r2 <= nr
    phi1 <- lat[r]
    phi2 <- lat[pmin(pmax(r2, 1), nr)]
    x <- (sin(theta / 2)^2 - sin((phi2 - phi1) / 2)^2) / (cos(phi1) * cos(phi2))
    h <- ifelse(x < 0, -1, floor(2 * asin(sqrt(pmin(pmax(x, 0), 1))) / rx))
    h <- pmin(h, nc - 1)
    # Settle the boundary with the distance itself
    up <- h >= 0 & h < nc - 1 & haversine_km(phi1, phi2, (h + 1) * rx) <= radius_km
    h <- h + up
    down <- h >= 0 & haversine_km(phi1, phi2, pmax(h, 0) * rx) > radius_km
    h <- h - down
    h[!in_grid] <- -1
    hw[, r] <- as.integer(h)
  }
  list(dr0 = as.integer(-R), hw = hw, rowmap = seq_len(nr))
}
