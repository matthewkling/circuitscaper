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
#' Current flows along the circuit's links: the resistors joining each cell
#' to its 8 neighbours (see [dp_circuit()]). The map is defined per link, as
#' the signed sum over origin–destination pairs of cells within `radius` of
#' each other,
#' \deqn{F_e = \frac{1}{W} \sum_{i,j} o_i\, d_j\, k(d_{ij})\, I_e(i,j),}
#' where \eqn{o} and \eqn{d} are origin and destination strength, \eqn{k} is
#' 1 for cells within `radius` of each other and 0 otherwise, \eqn{I_e(i,j)}
#' is the current through link \eqn{e} when one unit flows from \eqn{i} to
#' \eqn{j}, and \eqn{W = \sum_{i,j} o_i d_j k(d_{ij})} makes the pair weights
#' sum to one unit of flow. Pairs never span groups of cells that NA cells
#' separate (components), since no current passes between them. A cell's
#' value combines the links that meet at it, up to 8 (see `current` below),
#' each link being shared by the two cells it joins.
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
#' ## Directional and undirected maps
#' [dp_omni()] with a `destination` maps the undirected counterpart, from the
#' same pairs: their squared currents, so flows in opposite directions don't
#' cancel. [dp_directionality()] computes both maps at once, with their
#' ratio, which shows where movement between the two distributions is
#' one-way and where it runs both ways.
#'
#' ## Performance
#' The time is mostly factoring the circuit, and with `normalize`, its
#' uniform twin, which about doubles it; set `normalize = FALSE` to skip
#' that. Each map then takes one solve. To reuse factorizations across runs,
#' pass a circuit from [dp_circuit()].
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
#' @param normalize Logical. Also compute flow potential (the same flow on
#'   the uniform circuit, conductance 1 on the same cells) and normalized
#'   current. Default `TRUE`.
#' @param direction Logical. Also return the components of net flow.
#'   Default `TRUE`.
#' @param cell_value Character. How `current` sums a cell's links:
#'   `"absolute"` (default), half the sum of absolute current, as in
#'   Circuitscape's current maps; or `"rms"`, the square root of half the sum
#'   of squared current, as in [dp_omni()].
#'
#' @return A [terra::SpatRaster] with layers:
#' \describe{
#'   \item{current}{Half the sum of absolute current over a cell's links, as
#'     in Circuitscape's current maps, or with `cell_value = "rms"`, the
#'     square root of half the sum of squared current. Unlike Circuitscape,
#'     it leaves out the current injected or withdrawn at the cell itself, so
#'     origin and destination cells read lower: a cell that injects one unit,
#'     all leaving along its links, has `current` 1/2 rather than 1.}
#'   \item{flow_potential, normalized_current}{(with `normalize`) `current`
#'     on the uniform circuit, summarised the same way, and `current`
#'     divided by it: above 1 where the landscape channels the flow, below 1
#'     where it impedes it.}
#'   \item{flow_x, flow_y}{(with `direction`) Net flow through the cell
#'     towards the east and the north, in grid directions: half the sum
#'     over the cell's links of the current along the link times its unit
#'     direction.}
#' }
#' Three attributes say how much of the two distributions the map covers,
#' each between 0 and 1:
#' \describe{
#'   \item{`"origin_in_reach"`}{The share of origin strength on cells with
#'     any destination strength within `radius` and in the same component.
#'     This is the one that says whether most of the origin has a destination
#'     within reach: origin cells without one send nothing. A cell that is
#'     both origin and destination counts as reached, although its pair with
#'     itself moves nothing.}
#'   \item{`"destination_in_reach"`}{The same for destination strength: the
#'     share on cells with any origin strength within reach.}
#'   \item{`"pair_weight_in_reach"`}{The share of all origin–destination pair
#'     weight, \eqn{W / (\sum o \sum d)}, that is within `radius` and in the
#'     same component, and so carried by the map. It depends on the size of
#'     the domain relative to `radius`: where the distributions span many
#'     radii, most pairs are out of reach and the share is small, however
#'     closely the two distributions overlap. With `radius = Inf` and one
#'     component, it is 1.}
#' }
#'
#' @seealso [dp_omni()], [dp_directionality()], [cs_advanced()]
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
#' attr(near, "origin_in_reach")
#' attr(near, "pair_weight_in_reach")
#' \dontshow{JuliaConnectoR::stopJulia()}
#'
#' @export
dp_flux <- function(resistance, origin, destination, radius = Inf,
                    source_threshold = 0.01, radius_units = c("pixels", "km"),
                    resistance_is = "resistances", normalize = TRUE,
                    direction = TRUE, cell_value = c("absolute", "rms")) {
  radius_units <- match.arg(radius_units)
  cell_value <- match.arg(cell_value)
  normalize <- isTRUE(normalize)
  circuit <- dp_as_circuit(resistance, resistance_is, uniform = normalize)
  kernel <- dp_kernel(circuit$env$template, radius, radius_units)
  o <- dp_weights(circuit, origin, source_threshold, "origin")
  d <- dp_weights(circuit, destination, source_threshold, "destination")
  f <- dp_flux_values(circuit, o, d, kernel, normalize, cell_value)

  v <- cbind(current = f$current)
  if (normalize) v <- cbind(v, flow_potential = f$fp, normalized_current = f$nc)
  if (isTRUE(direction)) v <- cbind(v, flow_x = f$flow[, 1], flow_y = f$flow[, 2])
  out <- dp_to_raster(circuit, v, colnames(v))
  dp_set_coverage(out, f)
}


#' Directional Flow Values in Node Order
#'
#' Solves the flux injection on the circuit and, with `normalize`, on its
#' uniform twin. Returns per-node `current` (summarised by `cell_value`),
#' `flow` (x and y), and with `normalize`, `fp` and `nc`; the injection `b`,
#' the total pair weight `W` and the coverage shares (see `dp_set_coverage()`).
#' With `check = FALSE`, returns
#' `NULL` instead of an error when no pairs are within reach.
#' @noRd
dp_flux_values <- function(circuit, o, d, kernel, normalize, cell_value,
                           check = TRUE) {
  inj <- dp_call("flux_injection", circuit$env$id, o, d, kernel$dr0, kernel$hw,
                 kernel$rowmap)
  if (inj$W <= 0) {
    if (!check) return(NULL)
    stop("No origin and destination cells are within `radius` of each other ",
         "in the same connected part of the circuit, so there is no flow.",
         call. = FALSE)
  }
  b <- as.double(inj$b)
  summarise <- function(cells) {
    if (cell_value == "rms") sqrt(0.5 * cells[, 2]) else 0.5 * cells[, 1]
  }
  cells <- dp_call("flux", circuit$env$id, b)
  out <- list(current = summarise(cells), flow = 0.5 * cells[, 3:4, drop = FALSE],
              b = b, W = inj$W,
              coverage = c(origin_in_reach = inj$origin_in_reach,
                           destination_in_reach = inj$destination_in_reach,
                           pair_weight_in_reach = inj$pair_weight_in_reach))
  if (normalize) {
    out$fp <- summarise(dp_call("flux", circuit$env$uniform_id, b))
    out$nc <- ifelse(out$fp > 0, out$current / out$fp, NA_real_)
  }
  out
}


#' Set the Coverage Attributes
#'
#' Sets `"origin_in_reach"`, `"destination_in_reach"` and
#' `"pair_weight_in_reach"` on `x` from the `coverage` of
#' `dp_flux_values()`.
#' @noRd
dp_set_coverage <- function(x, f) {
  for (nm in names(f$coverage)) attr(x, nm) <- f$coverage[[nm]]
  x
}
