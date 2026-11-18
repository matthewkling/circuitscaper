#' Directional Flow Between Two Distributions
#'
#' \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
#'
#' Maps the net flow from an origin distribution to a destination
#' distribution, with its direction, in one solve: for example from present
#' to future habitat, from breeding to wintering grounds, or from source
#' populations to restoration sites. Flows in opposite directions cancel, so
#' the map shows net movement. For movement between the two distributions
#' without direction, where every pair counts whichever way it flows, see
#' [dp_omni()] with a `destination`.
#'
#' @details
#' The map is the signed sum over origin–destination pairs of cells within
#' `radius` of each other,
#' \deqn{F_e = \frac{1}{W} \sum_{i,j} o_i\, d_j\, k(d_{ij})\, I_e(i,j),}
#' where \eqn{o} and \eqn{d} are origin and destination strength, \eqn{k} is
#' 1 for cells within `radius` of each other and 0 otherwise, \eqn{I_e(i,j)}
#' is the current through link \eqn{e} when one unit flows from \eqn{i} to
#' \eqn{j}, and \eqn{W = \sum_{i,j} o_i d_j k(d_{ij})} makes the pair weights
#' sum to one unit of flow. Pairs never span groups of cells that NA cells
#' separate (components), since no current passes between them.
#'
#' The sum is linear in the pairs' currents, so it takes a single solve, of
#' the injection \eqn{b_i = (o_i\, (Kd)_i - d_i\, (Ko)_i) / W}, where
#' \eqn{(Kd)_i} is the destination strength within reach of cell \eqn{i} and
#' \eqn{(Ko)_i} the origin strength within reach of it. Each origin cell
#' sends flow in proportion to its strength and the destination strength
#' within its reach; each destination cell receives in proportion to its
#' strength and the origin strength within its reach. A cell's pair with
#' itself counts in \eqn{W} but moves nothing, so where origin and
#' destination overlap, flow cancels.
#'
#' With `radius = Inf` and one component, this is the injection
#' \eqn{b = o / \sum o - d / \sum d}: one unit enters at the origin and leaves
#' at the destination, wherever it has to travel. That is the minimum-energy
#' flow that turns the origin distribution into the destination one.
#'
#' Withdrawals are fixed, not grounds: each destination cell takes its share
#' however electrically far away it is. (With grounds, as in
#' [cs_advanced()], current drains into the nearest destination instead.)
#'
#' Swapping `origin` and `destination` reverses the flow: the same `current`,
#' with `flow_x` and `flow_y` negated.
#'
#' @inheritParams dp_omni
#' @param origin,destination [terra::SpatRaster]s or file paths on the same
#'   grid as `resistance`: origin and destination strength, e.g. habitat
#'   suitability in two periods or seasons. NA counts as 0.
#' @param radius Numeric. The dispersal radius: origin and destination cells
#'   are paired if their centres are at most this far apart. In pixels by
#'   default (see `radius_units`). Default `Inf`, no distance limit.
#' @param source_threshold Numeric. Cells with origin or destination strength
#'   below this are not origins or destinations. Default `0.01`.
#' @param direction Logical. Also return the components of net flow.
#'   Default `TRUE`.
#'
#' @return A [terra::SpatRaster] with layers:
#' \describe{
#'   \item{current}{Half the sum of absolute current over a cell's links, as
#'     in Circuitscape's current maps (without the injection term).}
#'   \item{flow_x, flow_y}{(with `direction`) Net flow through the cell
#'     towards the east and the north, in grid directions: half the sum
#'     over the cell's links of the current along the link times its unit
#'     direction.}
#' }
#' Attribute `"in_reach"`: the share of all origin–destination pair weight,
#' \eqn{W / (\sum o \sum d)}, that is within `radius` and in the same
#' component, and so carried by the map. A small share means most of the
#' origin has no destination within reach.
#'
#' @seealso [dp_omni()], [cs_advanced()]
#'
#' @examplesIf circuitscaper::cs_julia_available(circuitscape = FALSE)
#' resistance <- terra::rast(system.file("extdata/resistance.tif",
#'                                       package = "circuitscaper"))
#' origin <- terra::rast(system.file("extdata/source.tif", package = "circuitscaper"))
#' destination <- terra::rast(system.file("extdata/ground.tif", package = "circuitscaper"))
#' result <- dp_flux(resistance, origin, destination)
#' terra::plot(result)
#'
#' # Only pairs within 45 cells of each other
#' near <- dp_flux(resistance, origin, destination, radius = 45)
#' attr(near, "in_reach")
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_flux <- function(resistance, origin, destination, radius = Inf,
                    source_threshold = 0.01, radius_units = c("pixels", "km"),
                    resistance_is = "resistances", direction = TRUE) {
  radius_units <- match.arg(radius_units)
  circuit <- dp_as_circuit(resistance, resistance_is)
  kernel <- dp_kernel(circuit$env$template, radius, radius_units)
  o <- dp_weights(circuit, origin, source_threshold, "origin")
  d <- dp_weights(circuit, destination, source_threshold, "destination")
  inj <- dp_call("flux_injection", circuit$env$id, o, d, kernel$dr0, kernel$hw,
                 kernel$rowmap)
  if (inj$in_reach <= 0) {
    stop("No origin and destination cells are within `radius` of each other ",
         "in the same connected part of the circuit, so there is no flow.",
         call. = FALSE)
  }

  cells <- dp_call("flux", circuit$env$id, as.double(inj$b))
  out <- if (isTRUE(direction)) {
    dp_to_raster(circuit, 0.5 * cells[, c(1, 3, 4)], c("current", "flow_x", "flow_y"))
  } else {
    dp_to_raster(circuit, 0.5 * cells[, 1], "current")
  }
  attr(out, "in_reach") <- inj$in_reach
  out
}
