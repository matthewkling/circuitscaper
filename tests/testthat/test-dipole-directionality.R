# dp_directionality(): dp_flux() and dp_omni(destination = ) in one, and
# their ratio

test_that("dp_directionality's layers are dp_flux's and dp_omni's", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  dest <- dipole_test_grid(split = TRUE, seed = 7)$suitability
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  r <- dp_directionality(circuit, x$suitability, dest, radius = 5, seed = 3,
                         n_draws = 8, n_dipoles = 2000)
  expect_named(r, c("directionality", "flux_current", "flux_flow_potential",
                    "flux_normalized_current", "flow_x", "flow_y", "omni_current",
                    "omni_flow_potential", "omni_normalized_current"))
  f <- dp_flux(circuit, x$suitability, dest, radius = 5, cell_value = "rms")
  o <- dp_omni(circuit, radius = 5, source_strength = x$suitability,
               destination = dest, seed = 3, n_draws = 8, n_dipoles = 2000)
  vals <- function(r, n) terra::values(r[[n]], mat = FALSE)
  for (n in c("current", "flow_potential", "normalized_current")) {
    expect_equal(vals(r, paste0("flux_", n)), vals(f, n), tolerance = 1e-12)
    expect_equal(vals(r, paste0("omni_", n)), vals(o, n), tolerance = 1e-10)
  }
  for (n in c("flow_x", "flow_y")) expect_equal(vals(r, n), vals(f, n), tolerance = 1e-12)
  for (a in c("origin_in_reach", "destination_in_reach", "pair_weight_in_reach")) {
    expect_equal(attr(r, a), attr(f, a))
  }
  expect_equal(attr(r, "seed"), 3L)
  expect_equal(rownames(attr(r, "halves")),
               c("omni_current", "omni_normalized_current", "directionality"))

  # The ratio, with W the total pair weight
  od <- dp_node_values(circuit, x$suitability)
  dd <- dp_node_values(circuit, dest)
  od[is.na(od) | od < 0.01] <- 0
  dd[is.na(dd) | dd < 0.01] <- 0
  W <- attr(f, "pair_weight_in_reach") * sum(od) * sum(dd)
  cur <- vals(r, "omni_current")
  expect_equal(vals(r, "directionality"),
               ifelse(cur > 0, W * vals(r, "flux_current")^2 / cur^2, NA),
               tolerance = 1e-10)

  r2 <- dp_directionality(circuit, x$suitability, dest, radius = 5, seed = 3,
                          n_draws = 8, n_dipoles = 2000, normalize = FALSE)
  expect_named(r2, c("directionality", "flux_current", "flow_x", "flow_y",
                     "omni_current"))
  expect_equal(vals(r2, "directionality"), vals(r, "directionality"), tolerance = 1e-10)
})

# Exact ratio and undirected map for origin o and destination d (node
# values), with no radius
exact_directionality <- function(circuit, o, d) {
  gi <- dipole_graph_info(circuit)
  P <- outer(o, d) * outer(gi$comp, gi$comp, "==")
  undirected <- dipole_exact_cells(gi, (P + t(P)) / 2) / 2
  k <- dp_kernel(circuit$env$template, Inf, "pixels")
  f <- dp_flux_values(circuit, o, d, k, FALSE, "rms")
  list(undirected = undirected, ratio = f$W * f$current^2 / undirected, f = f, k = k,
       ok = undirected > 1e-12 * max(undirected))
}

test_that("centering removes the noise where flow is one-way", {
  skip_if_no_julia(circuitscape = FALSE)
  tmpl <- terra::rast(nrows = 9, ncols = 24, xmin = 0, xmax = 24, ymin = 0, ymax = 9,
                      crs = "EPSG:5070")
  circuit <- dp_circuit(terra::setValues(tmpl, 1), resistance_is = "conductances",
                        flow_potential = FALSE)
  col <- (circuit$env$cells - 1) %% 24 + 1
  o <- as.numeric(col <= 2)
  d <- as.numeric(col >= 23)
  e <- exact_directionality(circuit, o, d)
  high <- e$ok & e$ratio > 0.9
  expect_gt(sum(high), 50)
  err <- sapply(1:4, function(seed) {
    centered <- dp_random_values(circuit, o, d, e$k, seed, 32, 2000, FALSE, center = e$f)
    plain <- dp_random_values(circuit, o, d, e$k, seed, 32, 2000, FALSE)
    r_c <- e$f$W * e$f$current^2 / centered$cur2
    r_p <- e$f$W * e$f$current^2 / plain$cur2
    expect_true(all(r_c[e$ok] <= 1 + 1e-12))
    c(centered = stats::median(abs(r_c[high] - e$ratio[high])),
      plain = stats::median(abs(r_p[high] - e$ratio[high])))
  })
  expect_lt(max(err["centered", ]), 0.01)
  expect_lt(mean(err["centered", ]), mean(err["plain", ]) / 5)
})

test_that("centered estimates are unbiased and bounded on a patchy landscape", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  col <- (seq_len(terra::ncell(x$conductance)) - 1) %% 31 + 1
  origin <- terra::mask(terra::setValues(x$conductance, as.numeric(col <= 4)),
                        x$conductance)
  destination <- terra::mask(terra::setValues(x$conductance, as.numeric(col >= 28)),
                             x$conductance)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  e <- exact_directionality(circuit, dp_node_values(circuit, origin),
                            dp_node_values(circuit, destination))
  ok <- e$ok
  expect_true(all(e$ratio[ok] <= 1 + 1e-8))

  for (seed in 1:3) {
    r <- dp_directionality(circuit, origin, destination, n_draws = 32,
                           n_dipoles = 2000, seed = seed)
    got <- dp_node_values(circuit, r$directionality)
    # Never above 1, whatever the seed
    expect_true(all(got[ok] <= 1 + 1e-12))
    # Noise of about R (1 - R) * 1.4 / sqrt(n_draws)
    expect_lt(stats::median(abs(got[ok] - e$ratio[ok])), 0.1)
  }

  # The undirected map is still unbiased: averaged over seeds, it matches
  # the exact map
  runs <- sapply(1:8, function(s) {
    dp_node_values(circuit, dp_omni(circuit, radius = Inf, source_strength = origin,
                                    destination = destination, normalize = FALSE,
                                    n_draws = 128, n_dipoles = 2000, seed = s))^2
  })
  expect_equal(sum(runs[ok, ]) / ncol(runs), sum(e$undirected[ok]), tolerance = 0.03)
  expect_lt(stats::median(abs(rowMeans(runs)[ok] / e$undirected[ok] - 1)), 0.03)
})
