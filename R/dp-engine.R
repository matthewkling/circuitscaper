# Engine for the dipole methods: the Julia module (inst/julia/dipole.jl),
# circuit handles, and moving rasters between terra's cell order and the
# circuit's node order.


# Julia module -------------------------------------------------------------

#' Load the Dipole Julia Module
#'
#' Sets up Julia if needed, includes `dipole.jl` into the running Julia if
#' it isn't there (e.g., after a restart), and frees circuits whose R
#' handles were garbage-collected.
#' @noRd
dp_julia <- function() {
  ensure_julia(circuitscape = FALSE)
  if (!isTRUE(jl_eval("isdefined(Main, :CircuitscaperDipole)"))) {
    f <- system.file("julia", "dipole.jl", package = "circuitscaper")
    jl_eval(paste0("include(", jl_string(f), "); nothing"))
  }
  session <- dp_session()
  pending <- .cs_env$dp_free
  if (length(pending)) {
    .cs_env$dp_free <- list()
    ids <- unlist(lapply(pending, function(p) if (identical(p$session, session)) p$ids))
    if (length(ids)) dp_call("free!", as.integer(ids))
  }
  invisible(session)
}

#' Call a Function in the Dipole Julia Module
#'
#' Goes through `Base.invokelatest`: 'JuliaConnectoR''s evaluation loop
#' predates the module, and Julia >= 1.12 warns when old code reaches
#' bindings defined later.
#' @param fun Character. Function name in `CircuitscaperDipole`.
#' @param ... Arguments, translated by 'JuliaConnectoR'.
#' @return The result, with Julia structs translated to R lists.
#' @noRd
dp_call <- function(fun, ...) {
  f <- jl_eval(paste0("CircuitscaperDipole.", fun))
  out <- JuliaConnectoR::juliaCall("Base.invokelatest", f, ...)
  if (inherits(out, "JuliaProxy")) JuliaConnectoR::juliaGet(out) else out
}

#' The Running Julia's Dipole Session Token
#' @noRd
dp_session <- function() jl_eval("CircuitscaperDipole.SESSION")

#' A Progressor as a Julia Callback
#'
#' 'JuliaConnectoR' passes an R function to Julia as a callback, which Julia
#' calls (from its main task only) as `progress(message, amount)`; `NULL`
#' becomes `nothing`, and Julia then skips the calls.
#' @noRd
dp_julia_progress <- function(p) {
  if (is.null(p)) return(NULL)
  function(message, amount) {
    p(message, amount)
    NULL
  }
}


# Progress -----------------------------------------------------------------

#' A Progressor for a Dipole Run
#'
#' Progress goes through 'progressr': a run signals its steps, and whoever
#' calls it chooses whether and how to show them (`progressr::handlers()`,
#' `progressr::with_progress()`, `progressr::withProgressShiny()`). With no
#' handler active, nothing is shown, and the signals cost next to nothing.
#'
#' The progressor finishes when the calling function exits, so the bar
#' completes even if a run takes fewer steps than counted (e.g., when it
#' stops early with an error).
#' @param progress Logical. The user-facing `progress` argument; `FALSE`
#'   signals nothing.
#' @param steps Number of steps.
#' @return A `p(message, amount)` function, or `NULL` for no progress.
#' @noRd
dp_progressor <- function(progress, steps, envir = parent.frame()) {
  if (!isTRUE(progress) || steps <= 0) return(NULL)
  pr <- progressr::progressor(steps = steps, envir = envir)
  function(message = "", amount = 1) {
    pr(if (nzchar(message)) message else character(0), amount = amount)
    invisible(NULL)
  }
}

#' Signal a Progress Step
#'
#' Amount 0 announces a step (its message shows while it runs), amount 1
#' completes it.
#' @noRd
dp_tick <- function(p, message = "", amount = 1) {
  if (!is.null(p)) p(message, amount)
  invisible(NULL)
}

#' Steps to Build or Check a Circuit
#'
#' One per factorization that `dp_as_circuit()` will do: none for a
#' `dp_circuit` that is current and complete.
#' @param x From `dp_circuit_input()`.
#' @noRd
dp_factor_steps <- function(x, uniform) {
  if (!inherits(x, "dp_circuit")) return(1 + uniform)
  env <- x$env
  if (!identical(env$session, dp_julia())) return(1 + (uniform || env$uniform_id > 0))
  as.integer(uniform && env$uniform_id == 0)
}

#' Steps of a Batched Random Solve
#'
#' Per batch of draws, one step for sampling the injections and one per
#' circuit solved, as `run_dipoles()` in Julia reports them.
#' @param x From `dp_circuit_input()`, or a `dp_circuit`.
#' @noRd
dp_draw_steps <- function(x, n_draws, n_circuits, batch = 0L) {
  n_nodes <- if (inherits(x, "dp_circuit")) x$env$n_nodes else x$n_nodes
  dp_julia()
  b <- dp_call("batch_size", n_nodes, as.integer(batch))
  ceiling(n_draws / b) * (1 + n_circuits)
}


# Inputs -------------------------------------------------------------------

#' Read a Single-Layer Raster Argument
#' @noRd
dp_rast <- function(x, name) {
  if (is.character(x)) {
    if (length(x) != 1 || !file.exists(x)) {
      stop("`", name, "`: file not found: ", x, call. = FALSE)
    }
    x <- terra::rast(x)
  }
  if (inherits(x, "RasterLayer")) x <- terra::rast(x)
  if (!inherits(x, "SpatRaster")) {
    stop("`", name, "` must be a SpatRaster or a file path to a raster.",
         call. = FALSE)
  }
  if (terra::nlyr(x) != 1) {
    stop("`", name, "` must have one layer.", call. = FALSE)
  }
  x
}

#' Conductance Surface from a Resistance or Conductance Raster
#'
#' Cells with zero conductance (infinite resistance) become NA: they are not
#' part of the circuit.
#' @noRd
dp_conductance <- function(resistance, resistance_is = "resistances") {
  resistance_is <- match.arg(resistance_is, c("resistances", "conductances"))
  r <- dp_rast(resistance, "resistance")
  v <- terra::values(r, mat = FALSE)
  if (any(v < 0, na.rm = TRUE)) {
    stop("`resistance` has negative values.", call. = FALSE)
  }
  if (resistance_is == "resistances") {
    if (any(v == 0, na.rm = TRUE)) {
      stop("`resistance` has zero values (infinite conductance), which ",
           "the dipole methods don't support.", call. = FALSE)
    }
    v <- 1 / v
  } else if (any(is.infinite(v))) {
    stop("`resistance` has infinite conductances.", call. = FALSE)
  }
  v[!is.na(v) & (v == 0 | is.infinite(v))] <- NA
  terra::setValues(r, v)
}

#' A Raster's Values in a Circuit's Node Order
#' @param x SpatRaster with the circuit's geometry.
#' @noRd
dp_node_values <- function(circuit, x) {
  terra::values(x, mat = FALSE)[circuit$env$cells]
}

#' Node Values as a Raster on a Circuit's Grid
#' @noRd
dp_to_raster <- function(circuit, v, names) {
  v <- as.matrix(v)
  out <- matrix(NA_real_, terra::ncell(circuit$env$template), ncol(v))
  out[circuit$env$cells, ] <- v
  r <- terra::rast(circuit$env$template, nlyrs = ncol(v))
  r <- terra::setValues(r, out)
  names(r) <- names
  r
}


# Circuits -----------------------------------------------------------------

#' Build a Circuit in Julia
#'
#' Factors the conductance surface's circuit and, if `uniform`, its uniform
#' twin (conductance 1 on the same cells) for flow potential. Returns a
#' `dp_circuit`: a handle to the Julia-side factorizations, kept in an
#' environment so that a rebuild after a Julia restart updates every copy.
#'
#' Nodes are the non-NA cells, numbered down the columns of the raster (top
#' row first), as in the prototype; `cells` maps them to terra's row-major
#' cell numbers.
#' @param conductance SpatRaster from `dp_conductance()`.
#' @param uniform Logical. Also build the uniform circuit.
#' @param p A progressor from `dp_progressor()`, or `NULL`: each
#'   factorization is a step.
#' @noRd
new_dp_circuit <- function(conductance, uniform = TRUE, p = NULL) {
  env <- new.env(parent = emptyenv())
  env$conductance <- conductance
  env$template <- terra::rast(conductance)
  nr <- terra::nrow(conductance)
  nc <- terra::ncol(conductance)
  wide <- terra::as.matrix(conductance, wide = TRUE)
  valid <- !is.na(wide)
  k <- which(valid) - 1L
  env$cells <- (k %% nr) * nc + k %/% nr + 1
  env$id <- 0L
  env$uniform_id <- 0L
  circuit <- structure(list(env = env), class = "dp_circuit")
  dp_build(circuit, uniform, p)
  reg.finalizer(env, dp_finalize, onexit = FALSE)
  circuit
}

#' (Re)build a Circuit's Julia Side
#' @noRd
dp_build <- function(circuit, uniform, p = NULL) {
  env <- circuit$env
  env$session <- dp_julia()
  wide <- terra::as.matrix(env$conductance, wide = TRUE)
  valid <- !is.na(wide)
  wide[!valid] <- 0
  info <- dp_call("prepare", wide, valid, uniform, dp_julia_progress(p))
  env$id <- info$id
  env$uniform_id <- info$uniform_id
  env$n_nodes <- info$n_nodes
  env$n_links <- info$n_links
  env$n_components <- info$n_components
  invisible(circuit)
}

#' Queue a Garbage-Collected Circuit's Julia Side to be Freed
#'
#' Finalizers can run in the middle of other Julia calls, so this only
#' records the handles; `dp_julia()` frees them on the next call.
#' @noRd
dp_finalize <- function(env) {
  ids <- c(env$id, env$uniform_id)
  ids <- ids[ids > 0]
  if (length(ids) && !is.null(env$session)) {
    .cs_env$dp_free <- c(.cs_env$dp_free, list(list(session = env$session, ids = ids)))
  }
}

#' Check a Circuit Before Use
#'
#' The Julia side of a circuit lives only as long as the Julia process, and
#' circuitscaper restarts Julia when the thread count changes or after a
#' crash. A circuit built in an earlier Julia is rebuilt, with a message.
#' @param uniform Logical. The uniform circuit is needed too; build it if
#'   missing.
#' @param p A progressor, or `NULL`: each factorization is a step.
#' @noRd
dp_check_circuit <- function(circuit, uniform = FALSE, p = NULL) {
  if (!inherits(circuit, "dp_circuit")) {
    stop("`circuit` must be a dp_circuit object.", call. = FALSE)
  }
  env <- circuit$env
  session <- dp_julia()
  if (!identical(env$session, session)) {
    message("Julia has restarted since this circuit was built; rebuilding it.")
    dp_build(circuit, uniform || env$uniform_id > 0, p)
  } else if (uniform && env$uniform_id == 0) {
    env$uniform_id <- dp_call("prepare_uniform", env$id, dp_julia_progress(p))
  }
  invisible(circuit)
}

#' @export
print.dp_circuit <- function(x, ...) {
  env <- x$env
  cat("<dp_circuit> ", env$n_nodes, " nodes, ", env$n_links, " links, ",
      env$n_components, " connected component",
      if (env$n_components != 1) "s", "\n", sep = "")
  cat("grid: ", terra::nrow(env$template), " x ", terra::ncol(env$template),
      if (env$uniform_id > 0) "; with uniform circuit for flow potential",
      "\n", sep = "")
  invisible(x)
}


# Engine hooks ---------------------------------------------------------------

#' Random-Sign Dipoles
#'
#' Draws `n_draws` injections of `n_dipoles` random-sign unit dipoles each,
#' endpoints (i, j) with probability proportional to w1_i * w2_j * k_ij over
#' ordered pairs with i != j in the same connected component, and solves
#' them against the circuit (and, if `uniform`, its uniform twin).
#' @return A list: `S`, the sum of w1_i * w2_j * k_ij over those pairs, and
#'   `cells`, one nodes x 2 matrix per circuit of the per-node sums of
#'   squared link current over draws (columns: odd draws, even draws).
#' @param center Optional list with `b`, an injection in node order, and `W`,
#'   the pair weight it is normalized by (as from `dp_flux_values()`). Each
#'   dipole is then centered on the mean dipole, `W / S * b`, so the sums
#'   estimate the variance of the pairs' currents rather than their mean
#'   square.
#' @param p A progressor, or `NULL`: steps as counted by `dp_draw_steps()`.
#' @noRd
dp_random_dipoles <- function(circuit, w1, w2, kernel, seed, n_draws, n_dipoles,
                              uniform = FALSE, batch = 0L, center = NULL, p = NULL) {
  dp_check_circuit(circuit, uniform)
  env <- circuit$env
  ids <- c(env$id, if (uniform) env$uniform_id)
  cb <- if (is.null(center)) numeric(0) else as.double(center$b)
  cw <- if (is.null(center)) 0 else as.double(center$W)
  dp_call("random_dipoles", as.integer(ids), as.double(w1), as.double(w2),
          kernel$dr0, kernel$hw, kernel$rowmap, as.integer(seed),
          as.integer(n_draws), as.integer(n_dipoles), as.integer(batch), cb, cw,
          dp_julia_progress(p))
}

#' Accumulate Given Injections (Parity Hook)
#'
#' Solves the columns of `B` (nodes x draws, in node order) against the
#' circuit and returns the sums over draws of squared link currents, per
#' link and per node (the sum over a node's links), split by draw parity:
#' column 1 holds odd draws, column 2 even draws. This is the engine with
#' no sampling, for checking it against the prototype's `dp_accumulate()`.
#' @param uniform Logical. Use the uniform circuit.
#' @noRd
dp_accumulate_injections <- function(circuit, B, batch = 8L, uniform = FALSE) {
  dp_check_circuit(circuit, uniform)
  id <- if (uniform) circuit$env$uniform_id else circuit$env$id
  B <- as.matrix(B)
  storage.mode(B) <- "double"
  dp_call("accumulate_injections", id, B, as.integer(batch))
}
