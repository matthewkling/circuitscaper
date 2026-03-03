#' Write INI Configuration File
#'
#' Writes a named list of sections/key-value pairs as an INI file.
#'
#' @param config Named list of lists. Top-level names are sections, inner
#'   names are keys.
#' @param path Character. File path to write.
#' @return The file path (invisibly).
#' @noRd
write_ini <- function(config, path) {
  lines <- character()
  for (section in names(config)) {
    lines <- c(lines, paste0("[", section, "]"))
    items <- config[[section]]
    for (key in names(items)) {
      val <- items[[key]]
      if (is.logical(val)) {
        val <- if (val) "true" else "false"
      } else if (is.character(val)) {
        # Normalize Windows backslashes to forward slashes for Julia/Circuitscape
        val <- gsub("\\\\", "/", val)
      }
      lines <- c(lines, paste0(key, " = ", val))
    }
    lines <- c(lines, "")
  }
  writeLines(lines, path)
  invisible(path)
}


#' Validate Matching Raster Geometry
#'
#' Check that two SpatRasters have the same extent, resolution, and CRS.
#'
#' @param r1,r2 SpatRaster objects.
#' @param name1,name2 Character labels for error messages.
#' @return `TRUE` invisibly if they match; errors otherwise.
#' @noRd
validate_raster_match <- function(r1, r2, name1 = "raster1", name2 = "raster2") {
  if (!inherits(r1, "SpatRaster") || !inherits(r2, "SpatRaster")) {
    return(invisible(TRUE))
  }

  e1 <- terra::ext(r1)
  e2 <- terra::ext(r2)
  if (!isTRUE(all.equal(as.vector(e1), as.vector(e2), tolerance = 1e-8))) {
    stop(name1, " and ", name2, " have different extents.", call. = FALSE)
  }

  r1_res <- terra::res(r1)
  r2_res <- terra::res(r2)
  if (!isTRUE(all.equal(r1_res, r2_res, tolerance = 1e-8))) {
    stop(name1, " and ", name2, " have different resolutions.", call. = FALSE)
  }

  invisible(TRUE)
}


#' Validate Resistance Surface Values
#'
#' Warns if a SpatRaster resistance surface contains zero or negative values,
#' which can cause computational issues in Circuitscape/Omniscape.
#'
#' @param resistance A SpatRaster or file path. Only checked if SpatRaster.
#' @param resistance_is Character. "resistances" or "conductances".
#' @return NULL invisibly. Called for side effects (warnings).
#' @noRd
validate_resistance_values <- function(resistance, resistance_is = "resistances") {
  if (!inherits(resistance, "SpatRaster")) return(invisible(NULL))

  vals <- terra::values(resistance)
  vals <- vals[!is.na(vals)]

  if (length(vals) == 0) {
    warning("Resistance raster has no non-NA values.", call. = FALSE)
    return(invisible(NULL))
  }

  if (any(vals < 0)) {
    warning("Resistance raster contains negative values, which are not ",
            "physically meaningful for ", resistance_is, ".", call. = FALSE)
  }

  if (resistance_is == "resistances" && any(vals == 0)) {
    warning("Resistance raster contains zero values, which represent ",
            "infinite conductance and may cause computational issues.",
            call. = FALSE)
  }

  invisible(NULL)
}


#' Read Resistance Matrix from Circuitscape Output
#'
#' Parses the `*_resistances.out` or `*_resistances_3columns.out` file.
#'
#' @param dir Character. Output directory.
#' @param prefix Character. File prefix used by Circuitscape.
#' @return Numeric matrix of pairwise effective resistances.
#' @noRd
read_resistance_matrix <- function(dir, prefix) {
  # Try the standard matrix format first
  matrix_file <- file.path(dir, paste0(prefix, "_resistances.out"))
  if (file.exists(matrix_file)) {
    mat <- as.matrix(utils::read.table(matrix_file, header = FALSE, skip = 1))
    # First column is row labels
    rownames(mat) <- mat[, 1]
    mat <- mat[, -1, drop = FALSE]
    colnames(mat) <- rownames(mat)
    return(mat)
  }

  # Fall back to 3-column format
  three_col_file <- file.path(dir, paste0(prefix, "_resistances_3columns.out"))
  if (file.exists(three_col_file)) {
    df <- utils::read.table(three_col_file, header = FALSE)
    nodes <- sort(unique(c(df[[1]], df[[2]])))
    n <- length(nodes)
    mat <- matrix(0, n, n, dimnames = list(nodes, nodes))
    for (i in seq_len(nrow(df))) {
      mat[as.character(df[i, 1]), as.character(df[i, 2])] <- df[i, 3]
      mat[as.character(df[i, 2]), as.character(df[i, 1])] <- df[i, 3]
    }
    return(mat)
  }

  # one-to-all and all-to-one modes don't produce resistance files
  NULL
}
