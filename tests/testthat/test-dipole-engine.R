# The dipole engine: graph, factorization, batched solves and per-link
# accumulation, against the R prototype (SPEC oracle 2) and the exact
# small-grid target (oracle 1)

test_that("node order matches the prototype and terra's cells", {
  skip_if_no_julia(circuitscape = FALSE)
  proto <- dipole_prototype()
  x <- dipole_test_grid()
  circuit <- new_dp_circuit(x$conductance)
  g <- proto$dp_graph(x$conductance)

  expect_equal(circuit$env$n_nodes, g$n)
  expect_equal(dp_node_values(circuit, x$suitability),
               proto$dp_node_values(g, x$suitability))
  back <- dp_to_raster(circuit, dp_node_values(circuit, x$conductance), "c")
  expect_equal(terra::values(back), terra::values(x$conductance),
               ignore_attr = TRUE)
  # A layer that varies by row and column, to catch transposes
  rc <- terra::init(x$conductance, "cell")
  expect_equal(terra::values(dp_to_raster(circuit, dp_node_values(circuit, rc), "c")),
               terra::values(terra::mask(rc, x$conductance)), ignore_attr = TRUE)
})

test_that("links and conductances match the prototype", {
  skip_if_no_julia(circuitscape = FALSE)
  proto <- dipole_prototype()
  x <- dipole_test_grid()
  circuit <- new_dp_circuit(x$conductance)
  g <- proto$dp_graph(x$conductance)
  gi <- dipole_graph_info(circuit)
  expect_equal(gi$a, unlist(lapply(g$edges, `[[`, "a")))
  expect_equal(gi$b, unlist(lapply(g$edges, `[[`, "b")))
  expect_equal(gi$g, unlist(lapply(g$edges, `[[`, "g")), tolerance = 1e-14)
  expect_equal(circuit$env$n_components, 1)

  split <- new_dp_circuit(dipole_test_grid(split = TRUE)$conductance)
  expect_equal(split$env$n_components, 2)
})

parity_check <- function(conductance, suit, radius_km, n_draws = 5, m = 400) {
  proto <- dipole_prototype()
  g <- proto$dp_graph(conductance)
  g0 <- proto$dp_graph(terra::mask(terra::setValues(conductance, 1), conductance))
  w <- proto$dp_node_values(g, suit)
  w[is.na(w)] <- 0
  set.seed(1)
  B <- proto$dp_injections(g, w, n_draws, m, radius_km)
  want <- proto$dp_accumulate(g, B)
  want0 <- proto$dp_accumulate(g0, B)

  circuit <- new_dp_circuit(conductance)
  got <- dp_accumulate_injections(circuit, B, batch = 2)
  got0 <- dp_accumulate_injections(circuit, B, batch = 3, uniform = TRUE)
  # The prototype's column 1 holds even draws, column 2 odd draws
  expect_equal(got$n, c(ceiling(n_draws / 2), floor(n_draws / 2)))
  expect_equal(got$cells[, 1], want[, 2], tolerance = 1e-9)
  expect_equal(got$cells[, 2], want[, 1], tolerance = 1e-9)
  expect_equal(got0$cells[, 1], want0[, 2], tolerance = 1e-9)
  expect_equal(got0$cells[, 2], want0[, 1], tolerance = 1e-9)
  expect_lt(max(abs(got$cells - want[, 2:1])) / max(want), 1e-9)
}

test_that("accumulating given injections matches the prototype (oracle 2)", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  parity_check(x$conductance, x$suitability, radius_km = 8)
  parity_check(x$conductance, x$suitability, radius_km = Inf)
})

test_that("accumulation matches the prototype on the reference crop", {
  skip_if_no_julia(circuitscape = FALSE)
  ref <- terra::rast(test_path("fixtures", "crop_R6_reference.tif"))
  parity_check(ref$conductance, ref$source_strength, radius_km = 15, n_draws = 4, m = 2000)
})

test_that("the pair sum S covers exactly the pairs the sampler can draw", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  circuit <- new_dp_circuit(x$conductance)
  gi <- dipole_graph_info(circuit)
  w <- dp_node_values(circuit, x$suitability)
  nr <- terra::nrow(x$conductance)
  for (radius in c(1, 2.5, 6, Inf)) {
    k <- if (is.finite(radius)) dp_kernel_pixels(radius, nr) else dp_kernel_none()
    S <- dp_call("pair_sum", circuit$env$id, w, w, k$dr0, k$hw, k$rowmap)
    expect_equal(S, sum(dipole_pair_weights(circuit, gi, w, radius)), tolerance = 1e-12)
  }
})

test_that("results don't depend on batching and are reproducible", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  circuit <- new_dp_circuit(x$conductance)
  w <- dp_node_values(circuit, x$suitability)
  k <- dp_kernel_pixels(4, terra::nrow(x$conductance))
  run <- function(seed, batch) {
    dp_random_dipoles(circuit, w, w, k, seed = seed, n_draws = 10, n_dipoles = 300,
                      uniform = TRUE, batch = batch)
  }
  a <- run(7, 0)
  expect_identical(run(7, 0), a)
  # The solve's width changes rounding in the last bit, nothing more
  expect_equal(run(7, 3), a, tolerance = 1e-13)
  expect_equal(run(7, 10), a, tolerance = 1e-13)
  expect_false(isTRUE(all.equal(run(8, 0)$cells, a$cells)))

  # Every dipole stays within its component, so each draw sums to zero there
  B <- dp_call("injection_matrix", circuit$env$id, w, w, k$dr0, k$hw, k$rowmap, 7L, 6L, 300L)
  comp <- dipole_graph_info(circuit)$comp
  expect_equal(unname(rowsum(B, comp)), matrix(0, 2, 6))
  expect_true(all(B[w == 0, ] == 0))
})

# Oracle 1: the scaled estimator converges to the exact target with no bias.
# 16 independent runs of 256 draws; per-node z-scores from the runs' spread.
exact_check <- function(radius) {
  x <- dipole_test_grid(split = TRUE)
  circuit <- new_dp_circuit(x$conductance)
  w <- dp_node_values(circuit, x$suitability)
  k <- if (is.finite(radius)) dp_kernel_pixels(radius, terra::nrow(x$conductance)) else dp_kernel_none()
  m <- 1000
  n_draws <- 256
  runs <- lapply(1:16, function(seed) {
    r <- dp_random_dipoles(circuit, w, w, k, seed = seed, n_draws = n_draws,
                           n_dipoles = m, uniform = TRUE)
    lapply(c(r$cells, r$power), function(cl) r$S / m * rowSums(cl) / n_draws)
  })
  # Squared current, then power, on the circuit and its uniform twin
  for (u in 1:4) {
    gi <- dipole_graph_info(circuit, uniform = u %in% c(2, 4))
    weight <- if (u > 2) 1 / gi$g else 1
    exact <- dipole_exact_cells(gi, dipole_pair_weights(circuit, gi, w, radius), weight)
    est <- sapply(runs, `[[`, u)
    ok <- exact > 0
    mu <- rowMeans(est)[ok]
    se <- apply(est, 1, stats::sd)[ok] / sqrt(ncol(est))
    z <- (mu - exact[ok]) / se
    totals <- colSums(est[ok, ])
    ratio <- mean(totals) / sum(exact[ok])
    expect_lt(abs(ratio - 1), 3 * stats::sd(totals) / sqrt(length(totals)) / sum(exact[ok]) + 1e-3)
    expect_lt(stats::median(abs(mu / exact[ok] - 1)), 0.03)
    # As in the reference-crop test: z-scores only where current isn't
    # negligible, whose estimates are too skewed for the runs' spread
    keep <- exact[ok] > 1e-4 * max(exact[ok])
    expect_lt(mean(abs(z[keep]) > 4), 0.02)
  }
}

test_that("the estimator converges to the exact target, disk kernel (oracle 1)", {
  skip_if_no_julia(circuitscape = FALSE)
  exact_check(radius = 5)
})

test_that("the estimator converges to the exact target, no limit (oracle 1)", {
  skip_if_no_julia(circuitscape = FALSE)
  exact_check(radius = Inf)
})

test_that("the sampler draws pairs in proportion to w1_i w2_j k_ij", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  w2r <- dipole_test_grid(split = TRUE, seed = 7)$suitability
  circuit <- new_dp_circuit(x$conductance, uniform = FALSE)
  gi <- dipole_graph_info(circuit)
  w1 <- dp_node_values(circuit, x$suitability)
  w2 <- dp_node_values(circuit, w2r)
  w1[is.na(w1)] <- 0
  w2[is.na(w2)] <- 0
  nc <- terra::ncol(x$conductance)
  cell <- circuit$env$cells
  r <- (cell - 1) %/% nc + 1
  c <- (cell - 1) %% nc + 1
  # Kernel membership from the kernel's own offsets
  in_kernel <- function(k) {
    if (is.null(k$hw) || length(k$hw) == 0) return(matrix(TRUE, length(r), length(r)))
    dr <- outer(r, r, function(a, b) b - a)
    dc <- abs(outer(c, c, function(a, b) b - a))
    d <- dr - k$dr0 + 1
    ok <- d >= 1 & d <= nrow(k$hw)
    h <- matrix(-1, length(r), length(r))
    kr <- k$rowmap[r]
    h[ok] <- k$hw[cbind(d[ok], kr[row(d)[ok]])]
    ok & dc <= h
  }
  kernels <- list(pixels = dp_kernel(circuit$env$template, 2.5, "pixels"),
                  km = dp_kernel(circuit$env$template, 3, "km"),
                  none = dp_kernel(circuit$env$template, Inf, "pixels"))
  n <- 2e5
  for (nm in names(kernels)) {
    k <- kernels[[nm]]
    P <- outer(w1, w2) * in_kernel(k) * outer(gi$comp, gi$comp, "==")
    diag(P) <- 0
    S <- dp_call("pair_sum", circuit$env$id, w1, w2, k$dr0, k$hw, k$rowmap)
    expect_equal(S, sum(P), tolerance = 1e-12, label = paste(nm, "S"))
    pairs <- dp_call("sample_pairs", circuit$env$id, w1, w2, k$dr0, k$hw, k$rowmap, 3L,
                     as.integer(n))
    # Only pairs with positive weight: within the kernel, same component, i != j
    expect_true(all(P[pairs] > 0), label = paste(nm, "support"))
    # Marginals of i and j, and the distribution of offsets, match P / S
    z <- function(obs, p) {
      e <- n * p
      max(abs(obs[e > 0] - e[e > 0]) / sqrt(e[e > 0]))
    }
    nn <- length(w1)
    expect_lt(z(tabulate(pairs[, 1], nn), rowSums(P) / S), 5, label = paste(nm, "i"))
    expect_lt(z(tabulate(pairs[, 2], nn), colSums(P) / S), 5, label = paste(nm, "j"))
    if (nm != "none") {
      off <- function(i, j) paste(r[j] - r[i], c[j] - c[i])
      ij <- which(P > 0, arr.ind = TRUE)
      e <- tapply(P[ij], off(ij[, 1], ij[, 2]), sum) / S
      obs <- table(factor(off(pairs[, 1], pairs[, 2]), levels = names(e)))
      expect_lt(z(as.vector(obs), as.vector(e)), 5, label = paste(nm, "offsets"))
    }
  }
})
