# dp_isolation(): per-cell effective resistance to targets

# Exact layers from a dense solve: resistance to the target distribution and
# mean resistance to targets, for target weights t within a pixel `radius`
# (Inf: no limit), with each cell standing for the site of valid cells
# within `site` pixels in its component, and the targets in its own site
# (the cell itself, for single cells) left out. Also returns the target
# area (target strength times `area`, per node, summed over targets). Also
# returns the reach A and the cells' contact resistance.
isolation_exact <- function(circuit, t, radius, site = 0, uniform = FALSE, area = 1) {
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
  # Sites: row i marks i's site, the valid cells within `site` in its
  # component
  S <- dipole_pair_weights(circuit, gi, rep(1, n), site)
  diag(S) <- 1
  # Row i: t_j k_ij over j in i's component, beyond i's site
  P <- dipole_pair_weights(circuit, gi, rep(1, n), radius) * rep(t, each = n)
  P[S > 0] <- 0
  A <- rowSums(P)
  Q <- P / ifelse(A > 0, A, 1)
  # Site averaging: row i is uniform over i's site
  S <- S / rowSums(S)
  M <- S - Q %*% S
  XS <- S %*% X %*% t(S)
  R <- outer(diag(XS), diag(XS), "+") - 2 * XS
  out <- cbind(resistance = rowSums((M %*% X) * M),
               mean_resistance = rowSums(Q * R))
  out[A == 0, ] <- NA
  contact <- 1 / as.numeric(rowsum(c(gi$g, gi$g), c(gi$a, gi$b))[as.character(seq_len(n)), 1])
  list(values = out, A = A, R = R, contact = contact,
       area = rowSums(P * rep(area, each = n)))
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

test_that("the continuous-habitat reference is its exact isolation", {
  skip_if_no_julia(circuitscape = FALSE)
  # The reference's own grid for radius 4 and sites of 1: 9 cells either side
  # of the centre (kernel 4, site 1, margin 4)
  tmpl <- terra::rast(nrows = 19, ncols = 19, xmin = 0, xmax = 19, ymin = 0, ymax = 19)
  flat <- terra::setValues(tmpl, 1)
  circuit <- dp_circuit(flat, resistance_is = "conductances")
  ex <- isolation_exact(circuit, rep(1, 361), 4, site = 1)
  centre <- terra::cellFromRowCol(tmpl, 10, 10)
  k <- dp_kernel(tmpl, 4)
  s <- dp_site_kernel(tmpl, 1, "pixels")
  ref <- dp_call("continuous_reference", circuit$env$id, k$dr0, k$hw, k$rowmap, s$dr0, s$hw,
                 s$rowmap, NULL)
  i <- match(centre, circuit$env$cells)
  expect_equal(ref$reach, rep(ex$A[i], 361))
  expect_equal(ref$resistance, rep(unname(ex$values[i, "resistance"]), 361), tolerance = 1e-8)
  # A wider margin hardly moves it: the grid stands in for the unbounded plane
  big <- dp_circuit(terra::rast(nrows = 41, ncols = 41, xmin = 0, xmax = 41, ymin = 0,
                                ymax = 41, vals = 1), resistance_is = "conductances")
  ex <- isolation_exact(big, rep(1, 41^2), 4, site = 1)
  expect_equal(ref$resistance[1], unname(ex$values[21 * 41 - 20, "resistance"]), tolerance = 1e-3)
})

test_that("cell areas are km2 where the grid gives them, and cells otherwise", {
  lonlat <- terra::rast(nrows = 30, ncols = 10, xmin = 0, xmax = 5, ymin = 0, ymax = 75,
                        crs = "EPSG:4326")
  a <- dp_cell_area(lonlat, 1:300)
  expect_equal(a$units, "km2")
  # A sphere, against terra's ellipsoid
  expect_lt(max(abs(a$area / terra::values(terra::cellSize(lonlat, unit = "km"))[, 1] - 1)),
            0.01)
  utm <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 1500, ymin = 0, ymax = 3000,
                     crs = "EPSG:32611")
  expect_equal(dp_cell_area(utm, 1:9), list(area = rep(0.5, 9), units = "km2"))
  none <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 3, ymin = 0, ymax = 3, crs = "")
  expect_equal(dp_cell_area(none, 1:9), list(area = rep(1, 9), units = "cells"))
})

test_that("accessibility layers measure the targets in reach as area", {
  skip_if_no_julia(circuitscape = FALSE)
  # Lon/lat cells of 1/60 degree near 36 N: areas vary by row
  x <- dipole_test_grid(split = TRUE)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  t <- dp_weights(circuit, x$suitability, 0.01, "source_strength")
  tmpl <- circuit$env$template
  area <- dp_cell_area(tmpl, circuit$env$cells)$area
  k <- dp_kernel(tmpl, 5)
  s <- dp_site_kernel(tmpl, 2, "pixels")
  ref <- dp_call("continuous_reference", circuit$env$id, k$dr0, k$hw, k$rowmap, s$dr0, s$hw,
                 s$rowmap, NULL)
  # The kernel's cells beyond the 13-cell site
  expect_equal(unique(ref$reach), sum(2 * k$hw + 1) - 13)
  ex <- isolation_exact(circuit, t, 5, site = 2, area = area)
  ok <- !is.na(ex$values[, 1])

  r <- dp_isolation(circuit, 5, x$suitability, n_draws = 2000, seed = 8,
                    accessibility = TRUE, se = TRUE)
  expect_equal(names(r), c("resistance", "mean_resistance", "normalized_resistance",
                           "normalized_mean_resistance", "target_area", "accessible_area",
                           "resistance_se", "mean_resistance_se", "normalized_resistance_se",
                           "normalized_mean_resistance_se", "accessible_area_se"))
  expect_equal(attr(r, "area_units"), "km2")
  v <- node_values(r, circuit)
  # Target area is exact
  expect_equal(v[ok, "target_area"], ex$area[ok])
  expect_true(all(is.na(v[!ok, "target_area"])))
  # Accessible area: target area times the reference over the cell's resistance
  target <- ex$area * ref$resistance / ex$values[, "resistance"]
  expect_lt(abs(stats::median(v[ok, "accessible_area"] / target[ok]) - 1), 0.03)
  expect_gt(cor(v[ok, "accessible_area"], target[ok], method = "spearman"), 0.995)
  z <- (v[ok, "accessible_area"] - target[ok]) / v[ok, "accessible_area_se"]
  expect_gt(mean(abs(z) < 4), 0.99)

  # The bias correction for inverting a noisy resistance: over few draws,
  # the median ratio stays near 1 (uncorrected, 1 + 2 / n_draws higher)
  few <- sapply(1:20, function(seed) {
    node_values(dp_isolation(circuit, 5, x$suitability, n_draws = 16, seed = seed,
                             accessibility = TRUE, normalize = FALSE), circuit)[, "accessible_area"]
  })
  expect_lt(abs(stats::median(rowMeans(few)[ok] / target[ok]) - 1), 0.04)

  # The reference resistance scales accessible area
  a <- dp_isolation(circuit, 5, x$suitability, n_draws = 4, seed = 1, accessibility = TRUE)
  b <- dp_isolation(circuit, 5, x$suitability, n_draws = 4, seed = 1, accessibility = TRUE,
                    reference_resistance = 3)
  expect_equal(terra::values(b$accessible_area), 3 * terra::values(a$accessible_area))
  expect_identical(terra::values(a$target_area), terra::values(b$target_area))
  # Without accessibility, the other layers are unchanged
  c0 <- dp_isolation(circuit, 5, x$suitability, n_draws = 4, seed = 1)
  expect_identical(terra::values(c0), terra::values(a[[names(c0)]]))
  expect_null(attr(c0, "area_units"))

  # Wider reach: more target area everywhere, and more accessible area in the
  # median (not at every cell: see ?dp_isolation)
  wide <- node_values(dp_isolation(circuit, 9, x$suitability, n_draws = 200, seed = 1,
                                   accessibility = TRUE, normalize = FALSE), circuit)
  narrow <- node_values(dp_isolation(circuit, 5, x$suitability, n_draws = 200, seed = 1,
                                     accessibility = TRUE, normalize = FALSE), circuit)
  both <- ok & !is.na(wide[, "target_area"])
  expect_true(all(wide[both, "target_area"] >= narrow[both, "target_area"]))
  expect_gt(stats::median(wide[both, "accessible_area"] / narrow[both, "accessible_area"]), 1.5)

  # In continuous habitat of the reference resistance, away from the edges,
  # every target counts in full; with no CRS, areas are in cells
  flat <- terra::rast(nrows = 41, ncols = 41, xmin = 0, xmax = 41, ymin = 0, ymax = 41,
                      vals = 1, crs = "")
  f <- dp_isolation(flat, 5, flat, n_draws = 400, seed = 1, accessibility = TRUE,
                    normalize = FALSE)
  expect_equal(attr(f, "area_units"), "cells")
  ta <- terra::as.matrix(f$target_area, wide = TRUE)
  expect_equal(range(ta[6:36, 6:36]), rep(unique(ref$reach), 2))
  ratio <- terra::as.matrix(f$accessible_area, wide = TRUE)[10:32, 10:32] / ta[10:32, 10:32]
  # Cells share their draws: across 12 seeds this mean is 1.000, SD 0.010
  expect_lt(abs(mean(ratio) - 1), 0.04)
})

test_that("on lon/lat grids, the continuous-habitat reference follows latitude", {
  skip_if_no_julia(circuitscape = FALSE)
  # 0.5 degree cells from 40 to 70 degrees north, radius 120 km, sites 40 km
  tmpl <- terra::rast(nrows = 60, ncols = 40, xmin = 0, xmax = 20, ymin = 40, ymax = 70,
                      crs = "EPSG:4326")
  flat <- terra::setValues(tmpl, 1)
  circuit <- dp_circuit(flat, resistance_is = "conductances")
  k <- dp_kernel(tmpl, 120, "km")
  s <- dp_site_kernel(tmpl, 40, "km")
  ref <- dp_call("continuous_reference", circuit$env$id, k$dr0, k$hw, k$rowmap, s$dr0, s$hw,
                 s$rowmap, NULL)
  node_row <- terra::rowFromCell(tmpl, circuit$env$cells)
  A <- tapply(ref$reach, node_row, unique)
  R <- tapply(ref$resistance, node_row, unique)
  # Rows whose kernel and sites fit in the grid use their own kernel ...
  ext <- abs(k$dr0) + abs(s$dr0)
  full <- (1 + ext):(60 - ext)
  cells <- function(hw) sum(pmax(2 * hw + 1, 0))
  expect_equal(as.numeric(A[full]),
               vapply(full, function(r) cells(k$hw[, r]) - cells(s$hw[, r]), 0))
  # ... and rows near the top and bottom borrow the nearest full row's
  expect_equal(as.numeric(A[1:ext]), rep(as.numeric(A[min(full)]), ext))
  expect_equal(as.numeric(R[(60 - ext + 1):60]), rep(as.numeric(R[max(full)]), ext))
  # Cells narrow northwards, so more fit in reach, and sites hold more cells
  expect_gt(A[min(full)], A[max(full)])
  # Away from the edges, in a flat landscape every target counts in full,
  # and the target area is about the area of the ring in reach
  f <- dp_isolation(flat, 120, flat, site_radius = 40, radius_units = "km",
                    n_draws = 400, seed = 1, accessibility = TRUE, normalize = FALSE)
  rows <- (1 + 2 * ext):(60 - 2 * ext)
  ta <- terra::as.matrix(f$target_area, wide = TRUE)[rows, 10:31]
  ratio <- terra::as.matrix(f$accessible_area, wide = TRUE)[rows, 10:31] / ta
  expect_lt(abs(mean(ratio) - 1), 0.03)
  expect_lt(abs(stats::median(ta) / (pi * (120^2 - 40^2)) - 1), 0.1)
})

test_that("a cell's targets are those beyond its own site", {
  skip_if_no_julia(circuitscape = FALSE)
  tmpl <- terra::rast(nrows = 20, ncols = 30, xmin = 0, xmax = 30, ymin = 0, ymax = 20,
                      crs = "")
  cond <- terra::setValues(tmpl, 1)
  cond[terra::cellFromRowColCombine(tmpl, 5:9, 20:29)] <- NA   # a lake
  cond[terra::cellFromRowColCombine(tmpl, 6:8, 22:24)] <- 1    # a 3 x 3 island
  cond[terra::cellFromRowColCombine(tmpl, 7, 26:28)] <- 1      # a 1 x 3 islet
  circuit <- dp_circuit(cond, resistance_is = "conductances")
  r <- dp_isolation(circuit, 8, cond, n_draws = 8, seed = 1, accessibility = TRUE)
  v <- terra::values(r)
  # Every site on the islet is the whole islet, and the island's centre
  # site is the whole island: no targets beyond them. (Counting the targets
  # within the site gave a resistance of 0 up to rounding.)
  islet <- terra::cellFromRowCol(tmpl, 7, 26:28)
  centre <- terra::cellFromRowCol(tmpl, 7, 23)
  expect_true(all(is.na(v[c(islet, centre), ])))
  # The island's other cells have targets beyond their sites
  island <- terra::cellFromRowColCombine(tmpl, 6:8, 22:24)
  expect_false(anyNA(v[setdiff(island, centre), ]))
  # Single cells keep them: their targets are the other cells
  r0 <- dp_isolation(circuit, 8, cond, n_draws = 8, seed = 1, site_radius = 0)
  expect_false(anyNA(terra::values(r0)[c(islet, island), ]))
  # The dense oracle agrees, and target area counts only targets beyond the site
  t <- dp_weights(circuit, cond, 0.01, "source_strength")
  ex <- isolation_exact(circuit, t, 8, site = 2)
  nv <- node_values(r, circuit)
  expect_equal(attr(r, "area_units"), "cells")
  expect_identical(is.na(nv[, "resistance"]), is.na(ex$values[, "resistance"]))
  ok <- !is.na(ex$values[, 1])
  expect_equal(nv[ok, "target_area"], ex$A[ok])

  # A radius within the site leaves no targets anywhere
  expect_error(dp_isolation(circuit, 2, cond, site_radius = 2), "reach beyond")
  expect_error(dp_isolation(circuit, 1.5, cond, site_radius = 2), "reach beyond")
  expect_no_error(dp_isolation(circuit, 2.5, cond, site_radius = 2, n_draws = 2))
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
  expect_error(dp_isolation(cond, Inf, target, accessibility = TRUE), "finite `radius`")
  expect_error(dp_isolation(cond, 3, target, accessibility = TRUE, reference_resistance = 0),
               "reference_resistance")
})
