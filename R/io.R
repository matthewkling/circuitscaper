#' Ensure Input is an ASC File Path
#'
#' Coerces a SpatRaster or file path to an ASCII grid (.asc) file path suitable
#' for Circuitscape/Omniscape input.
#'
#' @param x A SpatRaster object or character file path.
#' @param dir Character. Directory to write the .asc file to.
#' @param name Character. Base name for the output file (without extension).
#'
#' @return Character. Path to the .asc file.
#' @noRd
ensure_asc <- function(x, dir, name) {
  if (is.character(x)) {
    if (!file.exists(x)) {
      stop("File not found: ", x, call. = FALSE)
    }
    return(normalizePath(x, mustWork = TRUE))
  }

  if (inherits(x, "SpatRaster")) {
    path <- file.path(dir, paste0(name, ".asc"))
    terra::writeRaster(x, path, overwrite = TRUE, NAflag = -9999)
    return(normalizePath(path, mustWork = TRUE))
  }

  stop("`", name, "` must be a SpatRaster or a file path to a raster.",
       call. = FALSE)
}


#' Get CRS from Input
#'
#' Extracts CRS from a SpatRaster or raster file. Used to reattach CRS to
#' output rasters.
#'
#' @param x A SpatRaster or file path.
#' @return Character. CRS in WKT format.
#' @noRd
get_input_crs <- function(x) {
  if (inherits(x, "SpatRaster")) {
    return(terra::crs(x))
  }
  if (is.character(x) && file.exists(x)) {
    r <- terra::rast(x)
    return(terra::crs(r))
  }
  ""
}


#' Parse Circuitscape Output Files
#'
#' Reads Circuitscape output rasters from the output directory and assembles
#' them into a multi-layer SpatRaster with named layers.
#'
#' @param dir Character. Output directory.
#' @param prefix Character. Output file prefix used by Circuitscape.
#' @param input_crs Character. CRS to assign to output rasters.
#'
#' @return SpatRaster with named layers.
#' @noRd
parse_cs_output <- function(dir, prefix, input_crs = "") {
  # Look for output raster files
  pattern <- paste0("^", prefix, ".*\\.(asc|tif)$")
  files <- list.files(dir, pattern = pattern, full.names = TRUE)

  # Filter to raster outputs (exclude .out text files)
  raster_files <- files[!grepl("_resistances", files)]
  raster_files <- raster_files[!grepl("\\.ini$", raster_files)]
  raster_files <- raster_files[!grepl("\\.out$", raster_files)]

  if (length(raster_files) == 0) {
    stop("No output raster files found in: ", dir, call. = FALSE)
  }

  # Read and stack rasters, forcing values into memory so the result

  # survives temp directory cleanup (terra::rast is lazy by default)
  layers <- lapply(raster_files, function(f) {
    r <- terra::rast(f)
    r[] <- terra::values(r)
    r
  })
  result <- if (length(layers) == 1) layers[[1]] else do.call(c, layers)

  # Name layers based on file names
  layer_names <- gsub(paste0("^", prefix, "_?"), "", basename(raster_files))
  layer_names <- gsub("\\.(asc|tif)$", "", layer_names)
  layer_names <- gsub("^_", "", layer_names)
  # Clean up Circuitscape file suffixes into readable layer names
  layer_names <- gsub("cum_curmap", "cumulative_current", layer_names)
  layer_names <- gsub("curmap", "current", layer_names)
  layer_names <- gsub("voltmap", "voltage", layer_names)
  layer_names[layer_names == ""] <- "cumulative_current"

  names(result) <- layer_names

  # Restore CRS
  if (nchar(input_crs) > 0) {
    terra::crs(result) <- input_crs
  }

  result
}


#' Parse Omniscape Output Files
#'
#' Reads Omniscape output rasters and assembles them into a multi-layer
#' SpatRaster.
#'
#' @param dir Character. Omniscape output directory.
#' @param input_crs Character. CRS to assign to output rasters.
#'
#' @return SpatRaster with named layers.
#' @noRd
parse_os_output <- function(dir, input_crs = "") {
  # Omniscape writes outputs to a specific subdirectory
  # Look for common output file names
  expected_names <- c(
    "cum_currmap" = "cumulative_current",
    "flow_potential" = "flow_potential",
    "normalized_cum_currmap" = "normalized_current"
  )

  raster_files <- character()
  layer_names <- character()

  for (fname in names(expected_names)) {
    # Check for .tif first, then .asc
    for (ext in c(".tif", ".asc")) {
      path <- file.path(dir, paste0(fname, ext))
      if (file.exists(path)) {
        raster_files <- c(raster_files, path)
        layer_names <- c(layer_names, expected_names[[fname]])
        break
      }
    }
  }

  if (length(raster_files) == 0) {
    # Fall back to finding any raster files
    all_files <- list.files(dir, pattern = "\\.(asc|tif)$",
                            full.names = TRUE, recursive = TRUE)
    if (length(all_files) == 0) {
      stop("No output raster files found in: ", dir, call. = FALSE)
    }
    raster_files <- all_files
    layer_names <- gsub("\\.(asc|tif)$", "", basename(all_files))
  }

  # Force values into memory so the result survives temp directory cleanup
  layers <- lapply(raster_files, function(f) {
    r <- terra::rast(f)
    r[] <- terra::values(r)
    r
  })
  result <- if (length(layers) == 1) layers[[1]] else do.call(c, layers)
  names(result) <- layer_names

  if (nchar(input_crs) > 0) {
    terra::crs(result) <- input_crs
  }

  result
}
