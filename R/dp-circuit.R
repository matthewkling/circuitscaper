#' Prepare a Circuit for the Dipole Methods
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Builds and factors the circuit for a resistance surface once, so that
#' several dipole-method runs on the same surface (different radii, source
#' strengths, seeds or methods) can reuse it. Pass the result as the
#' `resistance` argument of [dp_omni()], [dp_pairwise()] or [dp_flux()].
#'
#' The circuit is Circuitscape's default raster graph: every non-NA cell is
#' a node, joined to its 8 neighbours by links of conductance
#' \eqn{(c_u + c_v)/2}, divided by \eqn{\sqrt{2}} on diagonals. Cells with
#' zero conductance (infinite resistance) are left out. A tiny conductance
#' to ground (\eqn{10^{-12}} per cell) keeps the circuit solvable; the
#' dipole methods inject balanced currents, so it carries essentially no
#' current. Groups of cells with no links between them (separated by NA
#' cells) are separate circuits, and no current passes between them.
#'
#' The factorization lives in the Julia session. If Julia is restarted
#' (e.g., by [cs_setup()] with more threads, or after a crash), the circuit
#' is rebuilt automatically the next time it is used.
#'
#' @param resistance A [terra::SpatRaster] or file path: the resistance (or
#'   conductance) surface.
#' @param resistance_is Character. Whether `resistance` holds
#'   `"resistances"` (default) or `"conductances"`.
#' @param flow_potential Logical. Also factor the uniform circuit (the same
#'   cells with conductance 1) that flow potential and normalized current
#'   use. Default `TRUE`. If `FALSE`, it is built when first needed.
#'
#' @return A `dp_circuit` object.
#'
#' @seealso [dp_omni()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' circuit <- dp_circuit(resistance)
#' circuit
#' a <- dp_omni(circuit, radius = 10)
#' b <- dp_omni(circuit, radius = 20)
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_circuit <- function(resistance, resistance_is = "resistances",
                       flow_potential = TRUE) {
  new_dp_circuit(dp_conductance(resistance, resistance_is),
                 uniform = isTRUE(flow_potential))
}


#' A Circuit From a `resistance` Argument
#'
#' Passes a `dp_circuit` through (checked, and with the uniform circuit
#' added if `uniform`); builds one from a raster otherwise.
#' @noRd
dp_as_circuit <- function(resistance, resistance_is = "resistances", uniform = FALSE) {
  if (inherits(resistance, "dp_circuit")) {
    dp_check_circuit(resistance, uniform)
    return(resistance)
  }
  new_dp_circuit(dp_conductance(resistance, resistance_is), uniform)
}

#' Source Weights in Node Order
#'
#' NA counts as zero; values below `threshold` are set to zero.
#' @param x A SpatRaster or file path on the circuit's grid; `NULL` uses
#'   the circuit's conductance.
#' @noRd
dp_weights <- function(circuit, x, threshold, name) {
  x <- if (is.null(x)) circuit$env$conductance else dp_rast(x, name)
  if (!isTRUE(terra::compareGeom(x, circuit$env$template, crs = FALSE,
                                 stopOnError = FALSE))) {
    stop("`", name, "` must have the same extent, resolution and number of ",
         "rows and columns as `resistance`.", call. = FALSE)
  }
  if (!is.numeric(threshold) || length(threshold) != 1 || is.na(threshold)) {
    stop("The source threshold must be a number.", call. = FALSE)
  }
  w <- dp_node_values(circuit, x)
  w[is.na(w)] <- 0
  if (any(w < 0) || any(is.infinite(w))) {
    stop("`", name, "` must be non-negative and finite.", call. = FALSE)
  }
  w[w < threshold] <- 0
  if (!any(w > 0)) {
    stop("`", name, "` has no cells at or above the threshold within the ",
         "circuit.", call. = FALSE)
  }
  w
}

#' Check a Whole-Number Argument
#' @noRd
dp_count <- function(x, name, min = 1) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || x != round(x) || x < min ||
      x > .Machine$integer.max) {
    stop("`", name, "` must be a whole number of at least ", min, ".", call. = FALSE)
  }
  as.integer(x)
}

#' Seed for a Run
#'
#' `NULL` draws one from R's random number generator, so [set.seed()]
#' makes runs reproducible too.
#' @noRd
dp_seed <- function(seed) {
  if (is.null(seed)) return(sample.int(.Machine$integer.max, 1))
  dp_count(seed, "seed", min = 0)
}
