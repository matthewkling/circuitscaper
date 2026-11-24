# Settlement model prototype: dispersers wander the resistance surface, die
# at a constant rate per unit area and time, and settle in habitat at a rate
# proportional to its quality. See ../DESIGN.md.
#
# Plain R + Matrix, independent of the Julia engine. The graph is
# Circuitscape's: 8 neighbours, link conductance (c_u + c_v) / 2, diagonals
# divided by sqrt(2).

suppressMessages(library(Matrix))

# Graph of the valid cells of a conductance raster
settle_graph <- function(cond) {
  nr <- terra::nrow(cond); nc <- terra::ncol(cond)
  v <- matrix(terra::values(cond)[, 1], nr, nc, byrow = TRUE)
  valid <- is.finite(v) & v > 0
  id <- matrix(0L, nr, nc); id[valid] <- seq_len(sum(valid))
  # node order: column-major over valid cells; cell = terra cell number
  rc <- which(valid, arr.ind = TRUE)
  cell <- (rc[, 1] - 1) * nc + rc[, 2]
  a <- b <- g <- NULL
  for (d in list(c(0, 1), c(1, 0), c(1, 1), c(1, -1))) {
    r1 <- rc[, 1]; c1 <- rc[, 2]; r2 <- r1 + d[1]; c2 <- c1 + d[2]
    ok <- r2 >= 1 & r2 <= nr & c2 >= 1 & c2 <= nc
    ok[ok] <- valid[cbind(r2[ok], c2[ok])]
    u <- id[cbind(r1[ok], c1[ok])]; w <- id[cbind(r2[ok], c2[ok])]
    x <- (v[cbind(r1[ok], c1[ok])] + v[cbind(r2[ok], c2[ok])]) / 2
    if (all(d != 0)) x <- x / sqrt(2)
    a <- c(a, u); b <- c(b, w); g <- c(g, x)
  }
  n <- sum(valid)
  L <- sparseMatrix(c(a, b), c(b, a), x = -c(g, g), dims = c(n, n))
  diag(L) <- -rowSums(L)
  list(L = L, a = a, b = b, g = g, n = n, cell = cell, row = rc[, 1], col = rc[, 2],
       nr = nr, nc = nc, h = terra::res(cond)[1])
}

# Per-node ground conductances.
#
# On a grid of spacing h with 8 neighbours, the Laplacian approximates
# -(1 + sqrt(2)) h^2 div(c grad), so a rate per unit area becomes a ground
# conductance of rate * h^2 per cell. In terrain of conductance 1 with a
# single absorption rate a (per unit area), a disperser's position at
# absorption follows K0(r / l) with l = sqrt((1 + sqrt(2)) / a): mean
# distance (pi / 2) l. So a mean distance D sets a = (1 + sqrt(2)) / l^2,
# l = 2 D / pi.
#
# Two such distances, set independently:
# - `distance`: mean distance travelled before death, in terrain of
#   conductance 1, without settling. Sets the death rate, everywhere.
# - `settle_distance`: mean distance travelled through continuous habitat
#   of quality 1 before settling, without death. Sets the settlement rate,
#   times habitat quality t.
# Holding settle_distance fixed, a longer `distance` only lowers death, so
# no cell's settlement probability can fall. In continuous habitat of
# quality 1, the share that settle is distance^2 / (distance^2 +
# settle_distance^2). Units of the distances and h must match.
absorption_rate <- function(D) (1 + sqrt(2)) / (2 * D / pi)^2
settle_grounds <- function(gr, t, distance, settle_distance) {
  list(death = rep(absorption_rate(distance) * gr$h^2, gr$n),
       settle = absorption_rate(settle_distance) * gr$h^2 * t)
}

# Probability that a disperser released at each cell settles (anywhere,
# its own cell included): solves (L + K) P = k_settle, by reciprocity.
settle_prob <- function(gr, k) {
  as.numeric(solve(gr$L + Diagonal(x = k$death + k$settle), k$settle))
}

# The same, but settling only beyond the site of radius `site` (in cells)
# around the release cell: one solve per cell, settlement grounds removed
# within the site. Exact, for small grids only.
settle_prob_away <- function(gr, k, site, nodes = seq_len(gr$n)) {
  vapply(nodes, function(i) {
    near <- (gr$row - gr$row[i])^2 + (gr$col - gr$col[i])^2 <= site^2
    ks <- k$settle * !near
    v <- solve(gr$L + Diagonal(x = k$death + ks), sparseVector(1, i, gr$n))
    sum(ks * as.numeric(v))
  }, 0)
}

# First contact: habitat (t > 0) absorbs on arrival; probability of reaching
# habitat before death
settle_prob_contact <- function(gr, t, distance) {
  k <- settle_grounds(gr, t, distance, 1)
  hab <- t > 0
  P <- numeric(gr$n); P[hab] <- 1
  keep <- !hab
  A <- (gr$L + Diagonal(x = k$death))[keep, keep]
  rhs <- -as.numeric(gr$L[keep, hab, drop = FALSE] %*% rep(1, sum(hab)))
  P[keep] <- as.numeric(solve(A, rhs))
  P
}

# Per-node sum over incident links of a per-link value
link_to_node <- function(gr, x) {
  as.numeric(rowsum(c(x, x), c(gr$a, gr$b))[as.character(seq_len(gr$n)), 1])
}

# Net flow: dispersers released in proportion to `w`, settling or dying.
# Per-node sum of |current| over incident links.
net_flow <- function(gr, k, w) {
  v <- as.numeric(solve(gr$L + Diagonal(x = k$death + k$settle), w))
  link_to_node(gr, abs(gr$g * (v[gr$a] - v[gr$b])))
}

# Gross flow, exact: sum over sources i of w_i * (current from a unit
# source at i)^2, per link, summed per node. Dense; small grids only.
gross_flow_exact <- function(gr, k, w) {
  G <- as.matrix(solve(gr$L + Diagonal(x = k$death + k$settle)))
  src <- which(w > 0)
  D <- G[gr$a, src, drop = FALSE] - G[gr$b, src, drop = FALSE]
  link_to_node(gr, gr$g^2 * as.numeric((D^2) %*% w[src]))
}

# Gross flow from random-sign monopoles: each draw injects s_i sqrt(w_i) at
# every source (s = +-1), and the mean squared current over draws is
# unbiased for gross_flow_exact. Returns the per-draw node sums.
gross_flow_draws <- function(gr, k, w, n_draws, seed = 1) {
  set.seed(seed)
  fac <- Cholesky(gr$L + Diagonal(x = k$death + k$settle))
  S <- matrix(sample(c(-1, 1), gr$n * n_draws, TRUE), gr$n) * sqrt(w)
  V <- as.matrix(solve(fac, S))
  sapply(seq_len(n_draws), function(j) {
    link_to_node(gr, (gr$g * (V[gr$a, j] - V[gr$b, j]))^2)
  })
}

# Node values back to a raster
to_rast <- function(gr, template, x) {
  out <- terra::rast(template); terra::values(out) <- NA
  out[gr$cell] <- x
  out
}
