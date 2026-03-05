#' Create a Focal Node Raster from Coordinates
#'
#' Convert a set of point coordinates into a focal node raster suitable for
#' use with [cs_pairwise()], [cs_one_to_all()], and [cs_all_to_one()]. Each
#' point is snapped to the nearest cell of the resistance raster and assigned
#' a sequential integer ID.
#'
#' @param coords A two-column matrix or data.frame of x and y coordinates.
#'   Each row represents one focal node. IDs are assigned sequentially
#'   (1, 2, 3, ...) based on row order.
#' @param resistance A [terra::SpatRaster] or file path to a raster, used as a
#'   template for extent, resolution, and CRS. The output raster will match
#'   this exactly.
#'
#' @return A [terra::SpatRaster] with 0 background and positive integer IDs at
#'   the cells nearest each coordinate. This can be passed directly to the
#'   `locations` argument of any `cs_*` function.
#'
#' @details
#' Coordinates are snapped to the nearest raster cell center using
#' [terra::cellFromXY()]. If two points snap to the same cell, an error is
#' raised. Points that fall outside the raster extent also produce an error.
#'
#' This function is called internally when you pass coordinates directly to
#' `cs_pairwise()`, `cs_one_to_all()`, or `cs_all_to_one()`. Use it
#' explicitly if you want to inspect or modify the focal node raster before
#' running an analysis.
#'
#' @seealso [cs_pairwise()], [cs_one_to_all()], [cs_all_to_one()]
#'
#' @examples
#' \dontrun{
#' library(terra)
#' res <- rast(nrows = 10, ncols = 10, vals = runif(100, 1, 10))
#'
#' coords <- matrix(c(-140, 70,
#'                     -100, 30,
#'                      -60, 50), ncol = 2, byrow = TRUE)
#' locs <- cs_locations(coords, res)
#' plot(locs)
#'
#' # Equivalent to passing coords directly:
#' result <- cs_pairwise(res, coords)
#' }
#'
#' @export
cs_locations <- function(coords, resistance) {
  # Load from file if needed
  if (is.character(resistance)) {
    if (!file.exists(resistance)) {
      stop("File not found: ", resistance, call. = FALSE)
    }
    resistance <- terra::rast(resistance)
  }

  if (inherits(resistance, "RasterLayer")) {
    resistance <- terra::rast(resistance)
  }

  if (!inherits(resistance, "SpatRaster")) {
    stop("`resistance` must be a SpatRaster or RasterLayer, or a file path to a raster.",
         call. = FALSE)
  }

  # Coerce to matrix
  if (is.data.frame(coords)) {
    if (ncol(coords) < 2) {
      stop("`coords` must have at least 2 columns (x, y).", call. = FALSE)
    }
    coords <- as.matrix(coords[, 1:2])
  }

  if (!is.matrix(coords) || !is.numeric(coords)) {
    stop("`coords` must be a numeric matrix or data.frame with x and y columns.",
         call. = FALSE)
  }

  if (ncol(coords) < 2) {
    stop("`coords` must have at least 2 columns (x, y).", call. = FALSE)
  }
  coords <- coords[, 1:2, drop = FALSE]

  n <- nrow(coords)
  if (n < 2) {
    stop("At least 2 focal nodes are required.", call. = FALSE)
  }

  # Snap coordinates to raster cells
  cells <- terra::cellFromXY(resistance, coords)

  # Validate: all points within extent
  outside <- is.na(cells)
  if (any(outside)) {
    bad <- which(outside)
    stop("Coordinates outside raster extent at row(s): ",
         paste(bad, collapse = ", "), call. = FALSE)
  }

  # Validate: no duplicate cells
  if (anyDuplicated(cells)) {
    dupes <- cells[duplicated(cells)]
    stop("Multiple coordinates snap to the same raster cell. ",
         "Duplicated cell(s): ", paste(unique(dupes), collapse = ", "),
         call. = FALSE)
  }

  # Build output raster
  out <- terra::rast(resistance)
  terra::values(out) <- 0

  # Assign sequential IDs
  out[cells] <- seq_len(n)

  # Copy CRS from template
  terra::crs(out) <- terra::crs(resistance)

  out
}
