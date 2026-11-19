# dp_omni(): the reference crop (SPEC oracle 3) and the user-facing API

reference_crop <- function() terra::rast(test_path("fixtures", "crop_R6_reference.tif"))

layer <- function(r, name) terra::values(r[[name]], mat = FALSE)

test_that("dp_omni converges to the exact reference crop (oracle 3)", {
  skip_if_no_julia(circuitscape = FALSE)
  ref <- reference_crop()
  circuit <- dp_circuit(ref$conductance, resistance_is = "conductances")
  runs <- lapply(1:8, function(s) {
    dp_omni(circuit, radius = 6, source_strength = ref$suitability,
            n_draws = 128, n_dipoles = 2e4, seed = s)
  })
  for (l in c("current", "flow_potential")) {
    exact <- layer(ref, paste0("exact_", l))^2
    est <- sapply(runs, layer, name = l)^2
    totals <- colSums(est)
    se <- stats::sd(totals) / sqrt(length(totals))
    expect_lt(abs(mean(totals) - sum(exact)), 3 * se + 1e-3 * sum(exact))
    mu <- rowMeans(est)
    expect_lt(stats::median(abs(mu / exact - 1)), 0.04)
    # Per-cell z-scores only where current isn't negligible: estimates at
    # cells carrying < 1e-4 of the maximum are so skewed that 8 runs'
    # spread understates their noise. With 8 runs, z has t-like tails
    # (~0.5% beyond 4); 16 seed groups on Julia 1.10 and 1.12 gave <= 0.9%.
    keep <- exact > 1e-4 * max(exact)
    z <- (mu - exact) / (apply(est, 1, stats::sd) / sqrt(ncol(est)))
    expect_lt(mean(abs(z[keep]) > 4), 0.02)
    expect_lt(stats::quantile(abs(mu[keep] / exact[keep] - 1), 0.95), 0.12)
  }
})

test_that("dp_omni resembles Omniscape on the reference crop", {
  skip_if_no_julia(circuitscape = FALSE)
  ref <- reference_crop()
  d <- dp_omni(ref$conductance, radius = 6, source_strength = ref$suitability,
               resistance_is = "conductances", seed = 1)
  expect_named(d, c("current", "flow_potential", "normalized_current"))
  hab <- layer(ref, "source_strength") > 0
  rho <- function(a, b) stats::cor(a[hab], b[hab], method = "spearman")
  # The exact layers give 0.990 and 0.848; 32 draws add a little noise
  expect_gt(rho(layer(d, "current"), layer(ref, "omniscape_current")), 0.97)
  expect_gt(rho(layer(d, "normalized_current"),
                layer(ref, "omniscape_current") / layer(ref, "omniscape_flow_potential")),
            0.78)
  h <- attr(d, "halves")
  expect_equal(rownames(h), c("current", "normalized_current"))
  expect_true(all(h$spearman > 0.8))
  expect_equal(attr(d, "seed"), 1L)
})

test_that("dp_omni's scale doesn't depend on n_dipoles", {
  skip_if_no_julia(circuitscape = FALSE)
  ref <- reference_crop()
  circuit <- dp_circuit(ref$conductance, resistance_is = "conductances", flow_potential = FALSE)
  total <- function(m) {
    mean(sapply(1:4, function(s) {
      sum(layer(dp_omni(circuit, 6, ref$suitability, normalize = FALSE,
                        n_draws = 64, n_dipoles = m, seed = s), "current")^2)
    }))
  }
  expect_equal(total(500), total(2e4), tolerance = 0.05)
})

test_that("dp_omni is reproducible and reuses circuits", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  a <- dp_omni(x$conductance, radius = 4, source_strength = x$suitability,
               resistance_is = "conductances", n_draws = 8, n_dipoles = 2000, seed = 3)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  b <- dp_omni(circuit, radius = 4, source_strength = x$suitability, n_draws = 8,
               n_dipoles = 2000, seed = 3)
  expect_identical(terra::values(a), terra::values(b))
  expect_identical(attr(a, "halves"), attr(b, "halves"))

  # Without normalization, the same draws give the same current
  c1 <- dp_omni(circuit, radius = 4, source_strength = x$suitability, n_draws = 8,
                n_dipoles = 2000, seed = 3, normalize = FALSE)
  expect_named(c1, "current")
  expect_equal(terra::values(c1), terra::values(a$current))

  set.seed(10)
  d1 <- dp_omni(circuit, 4, x$suitability, n_draws = 4, n_dipoles = 500)
  set.seed(10)
  d2 <- dp_omni(circuit, 4, x$suitability, n_draws = 4, n_dipoles = 500)
  expect_identical(terra::values(d1), terra::values(d2))

  # NA cells stay NA, and no current crosses between components
  expect_identical(is.na(terra::values(a$current, mat = FALSE)),
                   is.na(terra::values(x$conductance, mat = FALSE)))
  expect_equal(terra::crs(a), terra::crs(x$conductance))
})

test_that("dp_omni handles km radii on lon/lat grids", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  w <- dp_node_values(circuit, x$suitability)
  w[is.na(w) | w < 0.01] <- 0
  k <- dp_kernel(circuit$env$template, 6, "km")
  S <- dp_call("pair_sum", circuit$env$id, w, w, k$dr0, k$hw, k$rowmap)

  # Brute force over pairs, by great-circle distance between cell centres
  gi <- dipole_graph_info(circuit)
  xy <- terra::xyFromCell(x$conductance, circuit$env$cells) * pi / 180
  d <- outer(seq_along(w), seq_along(w), function(i, j) {
    haversine_km(xy[i, 2], xy[j, 2], xy[j, 1] - xy[i, 1])
  })
  P <- outer(w, w) * (d <= 6) * outer(gi$comp, gi$comp, "==")
  diag(P) <- 0
  expect_equal(S, sum(P), tolerance = 1e-12)

  r <- dp_omni(circuit, radius = 6, radius_units = "km", source_strength = x$suitability,
               n_draws = 4, n_dipoles = 1000, seed = 1)
  expect_true(all(is.finite(terra::values(r$current, mat = FALSE)[!is.na(terra::values(x$conductance))])))
})

test_that("dp_omni with a destination targets origin-destination pairs without bias", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  fut <- dipole_test_grid(split = TRUE, seed = 7)$suitability
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  p <- dp_node_values(circuit, x$suitability)
  f <- dp_node_values(circuit, fut)
  p[is.na(p) | p < 0.01] <- 0
  f[is.na(f) | f < 0.01] <- 0
  k <- dp_kernel(circuit$env$template, 5, "pixels")
  gi <- dipole_graph_info(circuit)
  # Pair weights o_i d_j k_ij over ordered pairs (not symmetric)
  cell <- circuit$env$cells
  rr <- (cell - 1) %/% 31
  cc <- (cell - 1) %% 31
  P <- outer(p, f) * (outer(rr, rr, "-")^2 + outer(cc, cc, "-")^2 <= 25) *
    outer(gi$comp, gi$comp, "==")
  diag(P) <- 0
  S <- dp_call("pair_sum", circuit$env$id, p, f, k$dr0, k$hw, k$rowmap)
  expect_equal(S, sum(P), tolerance = 1e-12)

  # Squared current is symmetric in a pair, so the symmetric part of P is
  # the target's weight
  exact <- dipole_exact_cells(gi, (P + t(P)) / 2) / 2
  exact_power <- dipole_exact_cells(gi, (P + t(P)) / 2, 1 / gi$g) / 2
  runs <- lapply(1:12, function(s) {
    r <- dp_omni(circuit, radius = 5, source_strength = x$suitability,
                 destination = fut, normalize = FALSE, n_draws = 256,
                 n_dipoles = 1000, seed = s, power = TRUE)
    cbind(dp_node_values(circuit, r$current)^2, dp_node_values(circuit, r$power))
  })
  ok <- exact > 0
  for (k in 1:2) {
    want <- list(exact, exact_power)[[k]]
    est <- sapply(runs, function(x) x[, k])
    expect_equal(sum(est[ok, ]) / ncol(est), sum(want[ok]), tolerance = 0.01)
    expect_lt(stats::median(abs(rowMeans(est)[ok] / want[ok] - 1)), 0.03)
  }

  r <- dp_omni(circuit, radius = 5, source_strength = x$suitability,
               destination = fut, seed = 1, n_draws = 8, n_dipoles = 1000)
  expect_named(r, c("current", "flow_potential", "normalized_current"))
  r <- dp_omni(circuit, radius = 5, source_strength = x$suitability,
               destination = fut, seed = 1, n_draws = 8, n_dipoles = 1000, power = TRUE)
  expect_named(r, c("current", "flow_potential", "normalized_current", "power",
                    "normalized_power"))
  # Same draws, so power doesn't change the other layers
  r0 <- dp_omni(circuit, radius = 5, source_strength = x$suitability,
                destination = fut, seed = 1, n_draws = 8, n_dipoles = 1000)
  expect_identical(terra::values(r[[1:3]]), terra::values(r0))
  expect_equal(terra::values(r$normalized_power, mat = FALSE),
               {
                 fp <- dp_omni(terra::mask(x$conductance * 0 + 1, x$conductance),
                               radius = 5, source_strength = x$suitability,
                               destination = fut, seed = 1, n_draws = 8,
                               n_dipoles = 1000, power = TRUE, normalize = FALSE,
                               resistance_is = "conductances")
                 p <- terra::values(r$power, mat = FALSE)
                 u <- terra::values(fp$power, mat = FALSE)
                 ifelse(u > 0, p / u, NA)
               }, tolerance = 1e-8)
})

test_that("dp_omni checks its inputs", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  expect_error(dp_omni(circuit, radius = 0.5), "smaller than a cell")
  expect_error(dp_omni(circuit, radius = 4, source_strength = x$suitability * 0),
               "no cells at or above the threshold")
  expect_error(dp_omni(circuit, radius = 4, source_strength = terra::rast(nrows = 5, ncols = 5)),
               "same extent")
  expect_error(dp_omni(circuit, radius = 4, n_draws = 1), "n_draws")
  expect_error(dp_omni(circuit, radius = 4, n_dipoles = 0), "n_dipoles")
  # Two lone source cells farther apart than the radius: no pairs to draw
  s <- x$suitability * 0
  s[c(1, terra::ncell(s))] <- 1
  expect_error(dp_omni(circuit, radius = 3, source_strength = s), "No pairs")
  expect_error(dp_circuit(-x$conductance, resistance_is = "conductances"), "negative")
  expect_error(dp_circuit(x$conductance * 0), "zero values")
  expect_output(print(circuit), "dp_circuit")
})
