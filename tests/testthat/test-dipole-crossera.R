# dp_flux() against the prototype's cross-era net flux (SPEC oracle 5), and
# dp_pathways()

crossera_surfaces <- function() {
  ref <- terra::rast(test_path("fixtures", "crop_R6_reference.tif"))
  # A "future" that shifts habitat 10 cells east
  fut <- terra::shift(ref$suitability, dx = 10 * terra::xres(ref))
  fut <- terra::extend(fut, ref)
  fut <- terra::crop(fut, ref)
  fut[is.na(fut)] <- 0
  list(conductance = ref$conductance, present = ref$suitability, future = fut)
}

test_that("dp_flux matches the prototype's net flux (oracle 5)", {
  skip_if_no_julia(circuitscape = FALSE)
  s <- crossera_surfaces()
  proto <- dipole_prototype()
  g <- proto$dp_graph(s$conductance)
  ws <- proto$dp_node_values(g, s$present)
  wd <- proto$dp_node_values(g, s$future)
  V <- as.vector(Matrix::solve(g$fac, matrix(ws / sum(ws) - wd / sum(wd), ncol = 1),
                               system = "A"))
  acc <- numeric(g$n)
  for (e in g$edges) {
    x <- abs(e$g * (V[e$a] - V[e$b]))
    acc[e$a] <- acc[e$a] + x
    acc[e$b] <- acc[e$b] + x
  }
  want <- proto$dp_raster(g, acc / 2, "net_flux")

  got <- dp_flux(s$conductance, s$present, s$future, source_threshold = 0,
                 resistance_is = "conductances")
  expect_named(got, c("current", "flow_x", "flow_y"))
  expect_equal(terra::values(got$current, mat = FALSE),
               terra::values(want, mat = FALSE), tolerance = 1e-8)
  expect_equal(attr(got, "imbalance"), 0)
})

test_that("dp_flux gives the direction of flow", {
  skip_if_no_julia(circuitscape = FALSE)
  tmpl <- terra::rast(nrows = 15, ncols = 40, xmin = 0, xmax = 40, ymin = 0, ymax = 15,
                      crs = "EPSG:5070")
  cond <- terra::setValues(tmpl, 1)
  present <- terra::setValues(tmpl, 0)
  future <- present
  present[, 1:3] <- 1
  future[, 38:40] <- 1
  r <- dp_flux(cond, present, future, resistance_is = "conductances")
  mid <- as.matrix(r[8, 10:30])
  expect_true(all(mid[, "flow_x"] > 0))
  expect_true(all(abs(mid[, "flow_y"]) < 1e-8))
  # Mirror symmetry about the middle row
  fy <- terra::as.matrix(r$flow_y, wide = TRUE)
  expect_equal(fy[1:7, ], -fy[15:9, ], tolerance = 1e-8)
  # Westward if the eras swap
  w <- dp_flux(cond, future, present, resistance_is = "conductances", direction = TRUE)
  expect_equal(terra::values(w$flow_x), -terra::values(r$flow_x), tolerance = 1e-8)
  expect_named(dp_flux(cond, present, future, resistance_is = "conductances",
                       direction = FALSE), "current")
})

test_that("dp_flux balances flow within each component", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)        # column 8 is NA
  present <- terra::setValues(x$conductance, 0)
  future <- present
  present[, 2:3] <- 1                         # left part: 2 columns, present
  present[, 20:21] <- 1                       # right part: present
  future[, 5:6] <- 1                          # left part: future
  future[, 25:26] <- 1                        # right part: future
  future[, 28:29] <- 1
  present <- terra::mask(present, x$conductance)
  future <- terra::mask(future, x$conductance)
  expect_warning(
    r <- dp_flux(x$conductance, present, future, resistance_is = "conductances"),
    "cross between parts"
  )
  p <- terra::values(present, mat = FALSE)
  f <- terra::values(future, mat = FALSE)
  left <- (seq_len(terra::ncell(present)) - 1) %% 31 < 7
  P_left <- sum(p[left], na.rm = TRUE) / sum(p, na.rm = TRUE)
  F_left <- sum(f[left], na.rm = TRUE) / sum(f, na.rm = TRUE)
  expect_equal(attr(r, "imbalance"), abs(P_left - F_left), tolerance = 1e-12)
  cur <- terra::values(r$current, mat = FALSE)
  expect_true(all(is.finite(cur[!is.na(cur)])))
  expect_lt(max(cur, na.rm = TRUE), 2)

  # No future habitat on the right: no flow there
  future2 <- future
  future2[, 9:31] <- 0
  r2 <- suppressWarnings(dp_flux(x$conductance, present, future2,
                                 resistance_is = "conductances"))
  cur2 <- terra::values(r2$current, mat = FALSE)
  expect_true(all(cur2[!left & !is.na(cur2)] == 0))
  expect_gt(max(cur2[left], na.rm = TRUE), 0)
})

test_that("dp_pathways targets present-to-future pairs without bias", {
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
  # Pair weights p_i f_j k_ij over ordered pairs (not symmetric)
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
  runs <- sapply(1:12, function(s) {
    r <- dp_pathways(circuit, x$suitability, fut, radius = 5, normalize = FALSE,
                     n_draws = 256, n_dipoles = 1000, seed = s)
    dp_node_values(circuit, r)^2
  })
  ok <- exact > 0
  expect_equal(sum(runs[ok, ]) / ncol(runs), sum(exact[ok]), tolerance = 0.01)
  expect_lt(stats::median(abs(rowMeans(runs)[ok] / exact[ok] - 1)), 0.03)

  r <- dp_pathways(circuit, x$suitability, fut, radius = 5, seed = 1, n_draws = 8,
                   n_dipoles = 1000)
  expect_named(r, c("current", "flow_potential", "normalized_current"))
})
