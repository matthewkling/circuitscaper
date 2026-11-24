# dp_isolation(): per-cell effective resistance to targets

# Exact layers from a dense solve: resistance to the target distribution and
# mean resistance to targets, for target weights t within a pixel `radius`
# (Inf: no limit), each cell's own pair left out, with each cell standing
# for the site of valid cells within `site` pixels in its component. Also
# returns the reach A and the cells' contact resistance.
isolation_exact <- function(circuit, t, radius, site = 0, uniform = FALSE) {
  gi <- dipole_graph_info(circuit, uniform)
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
  # Row i: t_j k_ij over j != i in i's component
  P <- dipole_pair_weights(circuit, gi, rep(1, n), radius) * rep(t, each = n)
  A <- rowSums(P)
  Q <- P / ifelse(A > 0, A, 1)
  # Site averaging: row i is uniform over i's site
  S <- dipole_pair_weights(circuit, gi, rep(1, n), site)
  diag(S) <- 1
  S <- S / rowSums(S)
  M <- S - Q %*% S
  XS <- S %*% X %*% t(S)
  R <- outer(diag(XS), diag(XS), "+") - 2 * XS
  out <- cbind(resistance = rowSums((M %*% X) * M),
               mean_resistance = rowSums(Q * R))
  out[A == 0, ] <- NA
  contact <- 1 / as.numeric(rowsum(c(gi$g, gi$g), c(gi$a, gi$b))[as.character(seq_len(n)), 1])
  list(values = out, A = A, R = R, contact = contact)
}

node_values <- function(r, circuit) terra::values(r)[circuit$env$cells, , drop = FALSE]

test_that("dp_isolation converges to the exact values, across components", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  t <- dp_weights(circuit, x$suitability, 0.01, "source_strength")
  for (s in list(c(5, 0), c(Inf, 0), c(5, 2), c(Inf, 3))) {
    radius <- s[1]
    r <- dp_isolation(circuit, radius, x$suitability, site_radius = s[2], n_draws = 2000,
                      seed = 2, se = TRUE)
    v <- node_values(r, circuit)
    ex <- isolation_exact(circuit, t, radius, site = s[2])$values
    expect_identical(is.na(v[, "resistance"]), is.na(ex[, "resistance"]))
    ok <- !is.na(ex[, 1])
    for (nm in colnames(ex)) {
      z <- (v[ok, nm] - ex[ok, nm]) / v[ok, paste0(nm, "_se")]
      # Cells share their draws, so their errors don't average out: the
      # mean's error is up to about 2% here (8 seeds)
      expect_lt(abs(mean(v[ok, nm]) / mean(ex[ok, nm]) - 1), 0.05)
      expect_gt(cor(v[ok, nm], ex[ok, nm], method = "spearman"), 0.995)
      expect_gt(mean(abs(z) < 4), 0.99)
    }
    # Mean resistance is at least the resistance to the distribution
    expect_true(all(ex[ok, "mean_resistance"] >= ex[ok, "resistance"] - 1e-12))
  }
})

test_that("standard errors match the spread across independent runs", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  # Within one run, cells share their draws, so their errors move together;
  # calibration shows across runs. 30 runs give each cell's SD to about 13%.
  runs <- lapply(1:30, function(s) {
    node_values(dp_isolation(circuit, 6, x$suitability, n_draws = 40, seed = s,
                             se = TRUE), circuit)
  })
  ok <- !is.na(runs[[1]][, "resistance"])
  for (nm in c("resistance", "mean_resistance", "normalized_resistance",
               "normalized_mean_resistance")) {
    est <- sapply(runs, function(v) v[ok, nm])
    se <- sapply(runs, function(v) v[ok, paste0(nm, "_se")])
    ratio <- stats::median(apply(est, 1, stats::sd) / apply(se, 1, mean))
    expect_gt(ratio, 0.8)
    expect_lt(ratio, 1.25)
  }
})

test_that("sites reduce the dependence on a cell's own resistance", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  t <- dp_weights(circuit, x$suitability, 0.01, "source_strength")
  ex0 <- isolation_exact(circuit, t, 8, site = 0)
  ex3 <- isolation_exact(circuit, t, 8, site = 3)
  ok <- !is.na(ex0$values[, 1])
  # Contact resistance is exact and a lower bound on single-cell resistance
  r <- dp_isolation(circuit, 8, x$suitability, site_radius = 0, n_draws = 2,
                    contact = TRUE)
  expect_equal(names(r)[terra::nlyr(r)], "contact")
  expect_equal(node_values(r, circuit)[, "contact"], ex0$contact)
  expect_true(all(ex0$values[ok, "resistance"] >= ex0$contact[ok]))
  # A site of a few cells tracks the cell's own contact resistance less
  rho <- function(v) cor(v[ok], ex0$contact[ok], method = "spearman")
  expect_lt(rho(ex3$values[, "resistance"]), rho(ex0$values[, "resistance"]) - 0.1)

  # A site radius under one cell is the cell alone
  a <- dp_isolation(circuit, 8, x$suitability, site_radius = 0, n_draws = 4, seed = 1)
  b <- dp_isolation(circuit, 8, x$suitability, site_radius = 0.5, n_draws = 4, seed = 1)
  expect_identical(terra::values(a), terra::values(b))
  # The default is 2 pixels
  a <- dp_isolation(circuit, 8, x$suitability, n_draws = 4, seed = 1)
  b <- dp_isolation(circuit, 8, x$suitability, site_radius = 2, n_draws = 4, seed = 1)
  expect_identical(terra::values(a), terra::values(b))
})

test_that("normalized layers divide by the same draws on the uniform circuit", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  r <- dp_isolation(circuit, 6, x$suitability, n_draws = 2000, seed = 3)
  v <- node_values(r, circuit)
  t <- dp_weights(circuit, x$suitability, 0.01, "source_strength")
  ex <- isolation_exact(circuit, t, 6, site = 2)$values
  ux <- isolation_exact(circuit, t, 6, site = 2, uniform = TRUE)$values
  ok <- !is.na(ex[, 1])
  for (nm in colnames(ex)) {
    target <- ex[ok, nm] / ux[ok, nm]
    expect_lt(abs(stats::median(v[ok, paste0("normalized_", nm)] / target) - 1), 0.02)
    expect_gt(cor(v[ok, paste0("normalized_", nm)], target, method = "spearman"), 0.99)
  }

  # On a landscape of constant resistance, the normalized layers are that
  # resistance exactly: both circuits see the same draws
  flat <- terra::setValues(x$conductance, 2)
  flat <- terra::mask(flat, x$conductance)
  r <- dp_isolation(flat, 6, x$suitability, n_draws = 4, seed = 1)
  expect_equal(range(terra::values(r$normalized_resistance), na.rm = TRUE), c(2, 2))
  expect_equal(range(terra::values(r$normalized_mean_resistance), na.rm = TRUE), c(2, 2))
})

test_that("with a destination, each direction targets the other distribution", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  origin <- x$suitability
  destination <- terra::flip(x$suitability, "horizontal")
  both <- dp_isolation(circuit, 8, origin, destination = destination, n_draws = 8,
                       seed = 4, se = TRUE)
  expect_equal(names(both),
               c(paste0("origin_", names(dp_isolation(circuit, 8, origin, n_draws = 2,
                                                       se = TRUE))),
                 paste0("destination_", names(dp_isolation(circuit, 8, origin, n_draws = 2,
                                                            se = TRUE)))))
  # Same seed, same draws: the origin's layers are the destination's
  # isolation alone, and vice versa
  to_dest <- dp_isolation(circuit, 8, destination, n_draws = 8, seed = 4, se = TRUE)
  from_origin <- dp_isolation(circuit, 8, origin, n_draws = 8, seed = 4, se = TRUE)
  strip <- function(r, prefix) {
    r <- r[[grep(paste0("^", prefix), names(r))]]
    names(r) <- sub(paste0("^", prefix), "", names(r))
    terra::values(r)
  }
  expect_equal(strip(both, "origin_"), terra::values(to_dest))
  expect_equal(strip(both, "destination_"), terra::values(from_origin))
  expect_named(attr(both, "relative_se"),
               paste0(rep(c("origin_", "destination_"), each = 4),
                      c("resistance", "mean_resistance", "normalized_resistance",
                        "normalized_mean_resistance")))
})

test_that("mean resistance decomposes dp_omni's total power", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  w <- dp_weights(circuit, x$suitability, 0.01, "source_strength")
  ex <- isolation_exact(circuit, w, 6)
  # Sum over cells of w_i A_i mean_resistance_i is the total effective
  # resistance over ordered pairs, which is the total power of dp_omni
  total <- sum(w * ex$A * ex$values[, "mean_resistance"], na.rm = TRUE)
  omni <- dp_omni(circuit, 6, x$suitability, normalize = FALSE, power = TRUE,
                  n_draws = 400, seed = 5)
  expect_lt(abs(sum(terra::values(omni$power), na.rm = TRUE) / total - 1), 0.05)
  r <- dp_isolation(circuit, 6, x$suitability, site_radius = 0, normalize = FALSE,
                    n_draws = 400, seed = 5)
  est <- sum(w * ex$A * node_values(r, circuit)[, "mean_resistance"], na.rm = TRUE)
  expect_lt(abs(est / total - 1), 0.05)
})

test_that("dp_isolation is reproducible and doesn't depend on batching", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  a <- dp_isolation(circuit, 5, x$suitability, n_draws = 10, seed = 6)
  b <- dp_isolation(circuit, 5, x$suitability, n_draws = 10, seed = 6)
  expect_identical(terra::values(a), terra::values(b))
  expect_equal(attr(a, "seed"), 6L)
  expect_false(identical(terra::values(a),
                         terra::values(dp_isolation(circuit, 5, x$suitability,
                                                    n_draws = 10, seed = 7))))

  t <- dp_weights(circuit, x$suitability, 0.01, "source_strength")
  k <- dp_kernel(circuit$env$template, 5)
  s <- dp_site_kernel(circuit$env$template, 2, "pixels")
  run <- function(batch) {
    dp_call("isolation", c(circuit$env$id, circuit$env$uniform_id), cbind(t), k$dr0,
            k$hw, k$rowmap, s$dr0, s$hw, s$rowmap, 6L, 10L, as.integer(batch), NULL)
  }
  expect_equal(run(3)$dist, run(0)$dist, tolerance = 1e-12)
  expect_equal(run(3)$mean, run(0)$mean, tolerance = 1e-12)
})

test_that("dp_isolation checks its inputs", {
  skip_if_no_julia(circuitscape = FALSE)
  tmpl <- terra::rast(nrows = 9, ncols = 9, xmin = 0, xmax = 9, ymin = 0, ymax = 9)
  cond <- terra::setValues(tmpl, 1)
  # A lone target cell, cut off from the rest by NA cells
  cond[terra::cellFromRowColCombine(tmpl, 4:6, 4:6)] <- NA
  cond[terra::cellFromRowCol(tmpl, 5, 5)] <- 1
  target <- terra::setValues(tmpl, 0)
  target[terra::cellFromRowCol(tmpl, 5, 5)] <- 1
  expect_error(dp_isolation(cond, 3, target, resistance_is = "conductances"),
               "No cell has a target")
  expect_error(dp_isolation(cond, 3, target, n_draws = 1), "n_draws")
  expect_error(dp_isolation(cond, -1, target), "radius")
  expect_error(dp_isolation(cond, 3, target, site_radius = -1), "site_radius")
  expect_error(dp_isolation(cond, 3, target, site_radius = Inf), "site_radius")
})
