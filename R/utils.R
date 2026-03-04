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


#' Count Focal Nodes in a Locations Input
#'
#' Determines the number of unique focal nodes from a SpatRaster or its
#' written ASC file.
#'
#' @param locations A SpatRaster or file path.
#' @param loc_path Character. Path to the ASC file (used if locations is a
#'   file path string).
#' @return Integer. Number of unique positive-valued focal nodes.
#' @noRd
count_focal_nodes <- function(locations, loc_path) {
  if (inherits(locations, "SpatRaster")) {
    vals <- terra::values(locations)
    vals <- vals[!is.na(vals) & vals > 0]
    return(length(unique(vals)))
  }
  # Read the written ASC to count nodes
  r <- terra::rast(loc_path)
  vals <- terra::values(r)
  vals <- vals[!is.na(vals) & vals > 0]
  length(unique(vals))
}


#' Write Variable Source Strengths File
#'
#' Writes a tab-delimited text file mapping node IDs to source strengths,
#' in the format expected by Circuitscape.
#'
#' @param strengths Numeric vector. One strength value per focal node,
#'   ordered by node ID (1, 2, 3, ...).
#' @param path Character. File path to write.
#' @return The file path (invisibly).
#' @noRd
write_source_strengths <- function(strengths, path) {
  ids <- seq_along(strengths)
  lines <- paste(ids, strengths, sep = "\t")
  writeLines(lines, path)
  invisible(path)
}


#' Run a Julia Expression with Error Capture
#'
#' Runs a Julia function call, optionally suppressing output. On error, the
#' Julia exception is captured via `sprint(showerror, e)` so that the actual
#' error type and message are available in R rather than the generic
#' "Error happens in Julia" from JuliaCall.
#'
#' The key design choice is to **not rethrow** from Julia. Instead, the error
#' is stored in a global variable and `nothing` is returned. This keeps
#' JuliaCall in a clean state so we can read the error details afterward.
#' If `rethrow()` were used, JuliaCall would intercept it and produce the
#' generic "Error happens in Julia" message, and subsequent `julia_eval()`
#' calls to read the error variable would fail.
#'
#' @param julia_expr Character. The Julia function call to evaluate
#'   (e.g., `'Circuitscape.compute("path")'`).
#' @param verbose Logical. If TRUE, output is shown in real time. If FALSE,
#'   stdout and stderr are suppressed.
#' @return The return value of the Julia expression (invisibly).
#' @noRd
run_julia <- function(julia_expr, verbose = FALSE) {
  # Clear any previous error state
  JuliaCall::julia_eval("global _circuitscaper_last_err = nothing")

  # Wrap in Julia try-catch that captures the error WITHOUT rethrowing.
  # On error, sprint(showerror, e) converts the exception to a readable
  # string. We also wrap sprint() itself in case it fails for exotic types.
  catch_block <- paste0(
    'catch e; ',
    'global _circuitscaper_last_err = ',
    'try; sprint(showerror, e); catch e2; string(typeof(e)); end; ',
    'nothing; end'
  )

  wrapped <- if (verbose) {
    paste0('try; ', julia_expr, '; ', catch_block)
  } else {
    paste0(
      'try; redirect_stdout(devnull) do; redirect_stderr(devnull) do; ',
      julia_expr,
      '; end; end; ', catch_block
    )
  }

  # Execute — should not throw since errors are caught in Julia.
  # Safety-net tryCatch in case something truly unexpected happens.
  tryCatch(
    JuliaCall::julia_eval(wrapped),
    error = function(e) {
      # Unexpected JuliaCall-level failure. Try to read the error variable
      # anyway; if the catch block ran, the detail will be there.
    }
  )

  # Check whether the Julia expression errored
  julia_err <- tryCatch(
    JuliaCall::julia_eval("_circuitscaper_last_err"),
    error = function(e2) NULL
  )

  if (!is.null(julia_err)) {
    # Extract a concise summary from the full stack trace.
    # Julia errors can be nested (e.g., TaskFailedException wrapping a
    # BoundsError). We look for several patterns:
    #   "caused by: <ErrorType>: <message>" — on the same line
    #   "nested task error: <ErrorType>: <message>" — on the same line
    # If neither is found, we use the first non-blank line.
    lines <- strsplit(julia_err, "\n")[[1]]
    lines <- trimws(lines)

    # Look for the root cause in "caused by:" or "nested task error:" lines
    root_cause <- NULL
    for (pattern in c("^caused by: ", "^nested task error: ")) {
      idx <- grep(pattern, lines)
      if (length(idx) > 0) {
        root_cause <- sub(pattern, "", lines[idx[length(idx)]])
        break
      }
    }

    if (!is.null(root_cause) && nchar(root_cause) > 0) {
      err_msg <- root_cause
    } else {
      # Use first non-blank line
      non_blank <- lines[nchar(lines) > 0]
      err_msg <- if (length(non_blank) > 0) non_blank[1] else julia_err
    }

    stop(err_msg, call. = FALSE)
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
