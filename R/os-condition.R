#' Define a Condition for Conditional Omniscape Connectivity
#'
#' Creates a condition specification for use with the `condition` argument of
#' [os_run()]. Conditional connectivity restricts which source cells are
#' connected to each target, based on how their values on a condition layer
#' (e.g., climate, land cover class) compare. Conditions can compare
#' present-day values at both sources and targets, or present-day values at
#' sources against future values at targets (e.g., for climate-tracking
#' connectivity).
#'
#' @param present A single-layer [terra::SpatRaster] or file path giving
#'   present-day condition values. Must align with the resistance surface.
#' @param future Optional single-layer [terra::SpatRaster] or file path giving
#'   future condition values. If supplied, each source's *present* value is
#'   compared against the target's *future* value. If `NULL` (default), present
#'   values are used for both sources and targets.
#' @param type Character. How source and target values are compared:
#'   `"equal"` (connect only sources whose value equals the target's value;
#'   intended for categorical data) or `"within"` (connect only sources whose
#'   value falls within a range relative to the target's value; see `lower`
#'   and `upper`). If not specified, defaults to `"within"` when `lower` and
#'   `upper` are supplied and `"equal"` otherwise.
#' @param lower,upper Numeric. Required when `type = "within"`, and not used
#'   otherwise. A source is connected to a target only if
#'   `target + lower <= source <= target + upper`, or equivalently if
#'   `source - target` falls in `[lower, upper]`. For example, `lower = -1`
#'   and `upper = 0.5` connect sources whose values are up to 1 unit below
#'   or 0.5 units above the target's value. Either bound may be infinite
#'   (e.g., `upper = Inf` for a one-sided comparison).
#'
#' @details
#' Omniscape evaluates each moving-window target against every source cell in
#' the window, and sets the strength of any source that fails the comparison
#' to zero for that target. The target's value is summarized over its block
#' (see `block_size` in [os_run()]): the median for `"within"`, and the mode
#' for `"equal"`. When `block_size = 1` this is simply the target cell's value.
#'
#' Omniscape requires a condition value at every source cell. Source cells
#' with a missing (`NA`) present-day condition value are *not* filtered out;
#' they remain sources for every target. [os_run()] warns if it detects this.
#'
#' `"equal"` compares values exactly, so it is only meaningful for
#' categorical (integer-valued) layers; a warning is issued if a
#' `SpatRaster` supplied with `type = "equal"` contains non-integer values.
#'
#' Up to two conditions can be combined by passing a list of two
#' `os_condition()` objects to [os_run()]; a source must satisfy both to be
#' connected.
#'
#' @return An object of class `"os_condition"`: a list with elements
#'   `present`, `future`, `type`, `lower`, and `upper`.
#'
#' @references
#' Omniscape.jl conditional connectivity options:
#' \url{https://docs.circuitscape.org/Omniscape.jl/latest/usage/}
#'
#' @seealso [os_run()]
#'
#' @examplesIf circuitscaper::cs_julia_available()
#' library(terra)
#' temp_now <- rast(nrows = 20, ncols = 20, vals = rep(1:20, each = 20))
#' temp_future <- temp_now + 2
#'
#' # Climate-tracking: connect sources to targets whose future temperature is
#' # between 1 unit cooler and 3 units warmer than the source's present value
#' # (i.e., source - target_future within [-3, 1])
#' os_condition(temp_now, future = temp_future, lower = -3, upper = 1)
#'
#' # Categorical: connect only cells of the same land cover class
#' landcover <- rast(nrows = 20, ncols = 20, vals = sample(1:3, 400, TRUE))
#' os_condition(landcover, type = "equal")
#'
#' @export
os_condition <- function(present,
                         future = NULL,
                         type = c("equal", "within"),
                         lower = NULL,
                         upper = NULL) {

  present <- check_condition_layer(present, "present")
  if (!is.null(future)) {
    future <- check_condition_layer(future, "future")
    validate_raster_match(present, future, "present", "future")
  }

  has_bounds <- !is.null(lower) || !is.null(upper)
  if (missing(type)) {
    type <- if (has_bounds) "within" else "equal"
  } else {
    type <- match.arg(type)
  }

  if (type == "within") {
    if (is.null(lower) || is.null(upper)) {
      stop("`lower` and `upper` are both required when `type = \"within\"`. ",
           "Use -Inf or Inf for an unbounded side.", call. = FALSE)
    }
    check_bound(lower, "lower")
    check_bound(upper, "upper")
    if (lower > upper) {
      stop("`lower` must be less than or equal to `upper`.", call. = FALSE)
    }
  } else {
    if (has_bounds) {
      stop("`lower` and `upper` only apply when `type = \"within\"`.",
           call. = FALSE)
    }
    for (nm in c("present", "future")) {
      lyr <- if (nm == "present") present else future
      if (inherits(lyr, "SpatRaster") && has_noninteger_values(lyr)) {
        warning("The `", nm, "` layer contains non-integer values. ",
                "`type = \"equal\"` compares values exactly and is intended ",
                "for categorical data; consider `type = \"within\"` instead.",
                call. = FALSE)
      }
    }
  }

  structure(
    list(
      present = present,
      future = future,
      type = type,
      lower = if (type == "within") as.numeric(lower) else NULL,
      upper = if (type == "within") as.numeric(upper) else NULL
    ),
    class = "os_condition"
  )
}


#' @export
print.os_condition <- function(x, ...) {
  rule <- if (x$type == "within") {
    paste0("within: target + ", format(x$lower), " <= source <= target + ",
           format(x$upper))
  } else {
    "equal: source == target"
  }
  cat("<os_condition>", rule, "\n")
  cat("  present:", describe_condition_layer(x$present), "\n")
  if (!is.null(x$future)) {
    cat("  future: ", describe_condition_layer(x$future),
        "(compared at targets)\n")
  }
  invisible(x)
}


# Internal helpers --------------------------------------------------------

#' Validate and Normalize a Condition Layer Input
#' @return A SpatRaster or a character file path.
#' @noRd
check_condition_layer <- function(x, name) {
  if (inherits(x, "RasterLayer")) {
    x <- terra::rast(x)
  }
  if (inherits(x, "SpatRaster")) {
    if (terra::nlyr(x) != 1) {
      stop("`", name, "` must be a single-layer raster. To use two ",
           "conditions, pass a list of two os_condition() objects to ",
           "os_run().", call. = FALSE)
    }
    return(x)
  }
  if (is.character(x) && length(x) == 1) {
    if (!file.exists(x)) {
      stop("File not found for `", name, "`: ", x, call. = FALSE)
    }
    return(x)
  }
  stop("`", name, "` must be a SpatRaster or a file path to a raster.",
       call. = FALSE)
}


#' @noRd
check_bound <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x)) {
    stop("`", name, "` must be a single non-missing number.", call. = FALSE)
  }
  invisible(TRUE)
}


#' @noRd
has_noninteger_values <- function(r) {
  v <- terra::global(r != round(r), "max", na.rm = TRUE)[[1]]
  isTRUE(v > 0)
}


#' @noRd
describe_condition_layer <- function(x) {
  if (inherits(x, "SpatRaster")) {
    paste0("SpatRaster (", terra::nrow(x), " x ", terra::ncol(x), ")")
  } else {
    x
  }
}


#' Is an Object a Single Raster-Like Condition Input?
#' @noRd
is_raster_like <- function(x) {
  inherits(x, c("SpatRaster", "RasterLayer")) ||
    (is.character(x) && length(x) == 1)
}


#' Normalize the `condition` Argument of os_run()
#'
#' Converts the various accepted forms of `condition` into a list of one or
#' two `os_condition` objects, handling the deprecated `condition_type`
#' argument.
#'
#' @param condition NULL, a raster-like input, an `os_condition`, or a list of
#'   one or two of those.
#' @param condition_type Deprecated. NULL, or "equal"/"within".
#' @return NULL or a list of `os_condition` objects.
#' @noRd
resolve_conditions <- function(condition, condition_type = NULL) {
  if (!is.null(condition_type)) {
    warning("`condition_type` is deprecated and will be removed in a future ",
            "version. Use `condition = os_condition(x, type = ...)` instead.",
            call. = FALSE)
  }

  if (is.null(condition)) {
    return(NULL)
  }

  if (!is.null(condition_type)) {
    if (!is_raster_like(condition)) {
      stop("`condition_type` cannot be combined with os_condition() objects; ",
           "set `type` in os_condition() instead.", call. = FALSE)
    }
    condition_type <- match.arg(condition_type, c("within", "equal"))
    if (condition_type == "within") {
      stop("`condition_type = \"within\"` requires bounds. Use ",
           "`condition = os_condition(x, type = \"within\", lower = ..., ",
           "upper = ...)` instead.", call. = FALSE)
    }
    return(list(os_condition(condition, type = condition_type)))
  }

  as_condition <- function(x) {
    if (inherits(x, "os_condition")) return(x)
    if (is_raster_like(x)) return(os_condition(x, type = "equal"))
    stop("Each element of `condition` must be an os_condition() object, ",
         "a SpatRaster, or a file path.", call. = FALSE)
  }

  if (inherits(condition, "os_condition") || is_raster_like(condition)) {
    return(list(as_condition(condition)))
  }

  if (is.list(condition)) {
    if (!length(condition) %in% 1:2) {
      stop("Omniscape supports at most two conditions; `condition` has ",
           length(condition), " elements.", call. = FALSE)
    }
    return(lapply(unname(condition), as_condition))
  }

  stop("`condition` must be an os_condition() object, a list of up to two ",
       "os_condition() objects, a SpatRaster, or a file path.", call. = FALSE)
}


#' Check Condition Layers Against Resistance and Source Cells
#'
#' Validates that SpatRaster condition layers align with the resistance
#' surface, and warns if any layer has missing values at source cells (which
#' Omniscape does not filter, and which it requires to be present).
#'
#' @return NULL invisibly; called for its errors and warnings.
#' @noRd
check_conditions_against_inputs <- function(conditions,
                                            resistance,
                                            source_strength = NULL,
                                            source_threshold = 0,
                                            r_cutoff = Inf,
                                            resistance_is = "resistances") {
  for (i in seq_along(conditions)) {
    for (lyr_name in c("present", "future")) {
      lyr <- conditions[[i]][[lyr_name]]
      if (inherits(lyr, "SpatRaster") && inherits(resistance, "SpatRaster")) {
        validate_raster_match(resistance, lyr, "resistance",
                              paste0("condition ", i, " (", lyr_name, ")"))
      }
    }
  }

  # Identify source cells, where possible without reading files
  src <- NULL
  if (!is.null(source_strength)) {
    if (inherits(source_strength, "SpatRaster")) {
      validate_raster_match(resistance, source_strength,
                            "resistance", "source_strength")
      src <- !is.na(source_strength) & source_strength > source_threshold
    }
  } else if (inherits(resistance, "SpatRaster")) {
    src <- !is.na(resistance)
    if (is.finite(r_cutoff) && resistance_is == "resistances") {
      src <- src & resistance <= r_cutoff
    }
  }
  if (is.null(src)) return(invisible(NULL))

  for (i in seq_along(conditions)) {
    for (lyr_name in c("present", "future")) {
      lyr <- conditions[[i]][[lyr_name]]
      if (!inherits(lyr, "SpatRaster")) next
      n_missing <- terra::global(src & is.na(lyr), "sum", na.rm = TRUE)[[1]]
      if (isTRUE(n_missing > 0)) {
        consequence <- if (lyr_name == "present") {
          paste0("Omniscape does not filter sources with missing condition ",
                 "values, so these cells will act as sources for every target.")
        } else {
          paste0("Targets with missing future values may be compared ",
                 "incorrectly or cause Omniscape to fail.")
        }
        warning("Condition ", i, " (", lyr_name, " layer) is NA at ",
                n_missing, " source cell(s). ", consequence,
                " Consider filling the condition layer or masking these ",
                "cells out of `source_strength`.", call. = FALSE)
      }
    }
  }

  invisible(NULL)
}
