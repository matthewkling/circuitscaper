#' Create a Focal Node Raster from Coordinates
#'
#' Convert a set of point coordinates into a focal node raster. Each point is
#' snapped to the nearest cell of the resistance raster and assigned a
#' sequential integer ID. Called internally when coordinates are passed to
#' `cs_pairwise()`, `cs_one_to_all()`, or `cs_all_to_one()`.
#'
#' @param coords A two-column matrix or data.frame of x and y coordinates.
#' @param resistance A [terra::SpatRaster] or file path to a raster template.
#' @return A [terra::SpatRaster] with 0 background and positive integer IDs.
#' @noRd
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
