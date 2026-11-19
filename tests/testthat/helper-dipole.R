# Helpers for the dipole-method tests

# The reference R prototype (a verbatim copy of dev/dipole/prototype/dipole.R),
# in its own environment so its dp_*() functions don't mask the package's.
# Its parent is terra's namespace, since the prototype calls terra functions
# unqualified and other tests may change the search path.
dipole_prototype <- function() {
  skip_if_not_installed("Matrix")
  env <- new.env(parent = asNamespace("terra"))
  sys.source(test_path("fixtures", "dipole-prototype.R"), envir = env)
  env
}

# A small, non-square lon/lat test landscape: patchy conductance over four
# orders of magnitude, a barrier with a gap, a block of NA cells and patchy
# suitability. With `split`, a column of NA cells cuts it into two
# connected components.
dipole_test_grid <- function(nr = 23, nc = 31, split = FALSE, seed = 42) {
  withr::local_seed(seed)
  tmpl <- terra::rast(nrows = nr, ncols = nc, xmin = -110, xmax = -110 + nc / 60,
                      ymin = 36, ymax = 36 + nr / 60, crs = "EPSG:4326")
  smooth <- function(sd) {
    r <- terra::setValues(tmpl, stats::rnorm(terra::ncell(tmpl)))
    r <- terra::focal(r, w = matrix(1, 5, 5), fun = mean, na.rm = TRUE)
    (r - terra::global(r, "mean")[[1]]) / terra::global(r, "sd")[[1]] * sd
  }
  cond <- exp(smooth(1.5))
  cond[terra::cellFromRowColCombine(tmpl, 10:11, 3:20)] <- 1e-3
  cond[terra::cellFromRowColCombine(tmpl, 15:18, 22:26)] <- NA
  if (split) cond[terra::cellFromRowColCombine(tmpl, 1:nr, 8)] <- NA
  suit <- 1 / (1 + exp(-2 * smooth(1.5)))
  suit[suit < 0.2] <- 0
  suit <- terra::mask(suit, cond)
  list(conductance = cond, suitability = suit)
}

# Exact per-node sums over incident links of
#   T_e = sum over ordered pairs (i, j) of P_ij * I_e(i, j)^2,
# from a dense solve with one node grounded per connected component (exact
# for balanced injections). P is nodes x nodes; g, a, b, comp describe the
# graph, as from CircuitscaperDipole.graph_info.
# Per-node sums over incident links of the summed squared current over pairs,
# each link's term times `weight` (1 / gi$g for power)
dipole_exact_cells <- function(gi, P, weight = 1) {
  n <- length(gi$comp)
  L <- matrix(0, n, n)
  L[cbind(gi$a, gi$b)] <- -gi$g
  L[cbind(gi$b, gi$a)] <- -gi$g
  diag(L) <- -rowSums(L)
  X <- matrix(0, n, n)
  for (k in unique(gi$comp)) {
    nodes <- which(gi$comp == k)
    if (length(nodes) < 2) next
    keep <- nodes[-1]
    X[keep, keep] <- solve(L[keep, keep])
  }
  # sum over ordered pairs of P_ij (y_i - y_j)^2 = 2 y' (D - P) y, P symmetric
  C <- 2 * (diag(rowSums(P)) - P)
  Y <- gi$g * (X[gi$a, , drop = FALSE] - X[gi$b, , drop = FALSE])
  # weight = 1 / gi$g gives power instead of squared current
  Te <- rowSums((Y %*% C) * Y) * weight
  cells <- numeric(n)
  agg <- rowsum(c(Te, Te), c(gi$a, gi$b))
  cells[as.integer(rownames(agg))] <- agg[, 1]
  cells
}

# Pair weights w_i w_j k_ij over ordered pairs, i != j, same component,
# for a pixel disk of `radius` (Inf: no limit)
dipole_pair_weights <- function(circuit, gi, w, radius) {
  nr <- terra::nrow(circuit$env$template)
  nc <- terra::ncol(circuit$env$template)
  cell <- circuit$env$cells
  r <- (cell - 1) %/% nc + 1
  c <- (cell - 1) %% nc + 1
  P <- outer(w, w)
  if (is.finite(radius)) {
    P <- P * (outer(r, r, "-")^2 + outer(c, c, "-")^2 <= radius^2)
  }
  P <- P * outer(gi$comp, gi$comp, "==")
  diag(P) <- 0
  P
}

dipole_graph_info <- function(circuit, uniform = FALSE) {
  id <- if (uniform) circuit$env$uniform_id else circuit$env$id
  dp_call("graph_info", id)
}
