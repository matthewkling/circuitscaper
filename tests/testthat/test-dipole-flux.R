# dp_flux() against the prototype's net flux (SPEC oracle 5) and a dense
# brute-force solve

shifted_surfaces <- function() {
  ref <- terra::rast(test_path("fixtures", "crop_R6_reference.tif"))
  # A destination that shifts habitat 10 cells east
  dest <- terra::shift(ref$suitability, dx = 10 * terra::xres(ref))
  dest <- terra::extend(dest, ref)
  dest <- terra::crop(dest, ref)
  dest[is.na(dest)] <- 0
  list(conductance = ref$conductance, origin = ref$suitability, destination = dest)
}

# Pair weights o_i d_j k_ij over ordered pairs in the same component, a
# cell's pair with itself included, for a pixel disk of `radius`
flux_pair_weights <- function(circuit, gi, o, d, radius) {
  nc <- terra::ncol(circuit$env$template)
  cell <- circuit$env$cells
  r <- (cell - 1) %/% nc
  c <- (cell - 1) %% nc
  P <- outer(o, d) * outer(gi$comp, gi$comp, "==")
  if (is.finite(radius)) P <- P * (outer(r, r, "-")^2 + outer(c, c, "-")^2 <= radius^2)
  P
}

# Per-node half sums of |I| over incident links for injection b (with `rms`,
# the root of half the sum of I^2), from a dense solve with one node
# grounded per component
flux_exact_current <- function(gi, b, rms = FALSE) {
  n <- length(gi$comp)
  L <- matrix(0, n, n)
  L[cbind(gi$a, gi$b)] <- -gi$g
  L[cbind(gi$b, gi$a)] <- -gi$g
  diag(L) <- -rowSums(L)
  V <- numeric(n)
  for (k in unique(gi$comp)) {
    nodes <- which(gi$comp == k)
    if (length(nodes) < 2) next
    keep <- nodes[-1]
    V[keep] <- solve(L[keep, keep], b[keep])
  }
  I <- abs(gi$g * (V[gi$a] - V[gi$b]))
  if (rms) I <- I^2
  cells <- numeric(n)
  agg <- rowsum(c(I, I), c(gi$a, gi$b))
  cells[as.integer(rownames(agg))] <- agg[, 1]
  if (rms) sqrt(cells / 2) else cells / 2
}

flux_test_inputs <- function() {
  x <- dipole_test_grid(split = TRUE)
  dest <- dipole_test_grid(split = TRUE, seed = 7)$suitability
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances",
                        flow_potential = FALSE)
  o <- dp_node_values(circuit, x$suitability)
  d <- dp_node_values(circuit, dest)
  o[is.na(o) | o < 0.01] <- 0
  d[is.na(d) | d < 0.01] <- 0
  list(x = x, dest = dest, circuit = circuit, o = o, d = d,
       gi = dipole_graph_info(circuit))
}

test_that("dp_flux matches the prototype's net flux (oracle 5)", {
  skip_if_no_julia(circuitscape = FALSE)
  s <- shifted_surfaces()
  proto <- dipole_prototype()
  g <- proto$dp_graph(s$conductance)
  ws <- proto$dp_node_values(g, s$origin)
  wd <- proto$dp_node_values(g, s$destination)
  V <- as.vector(Matrix::solve(g$fac, matrix(ws / sum(ws) - wd / sum(wd), ncol = 1),
                               system = "A"))
  acc <- numeric(g$n)
  for (e in g$edges) {
    x <- abs(e$g * (V[e$a] - V[e$b]))
    acc[e$a] <- acc[e$a] + x
    acc[e$b] <- acc[e$b] + x
  }
  want <- proto$dp_raster(g, acc / 2, "net_flux")

  got <- dp_flux(s$conductance, s$origin, s$destination, source_threshold = 0,
                 resistance_is = "conductances")
  expect_named(got, c("current", "flow_potential", "normalized_current",
                     "flow_x", "flow_y"))
  expect_equal(terra::values(got$current, mat = FALSE),
               terra::values(want, mat = FALSE), tolerance = 1e-8)
  expect_equal(attr(got, "in_reach"), 1, tolerance = 1e-12)
})

test_that("flux injections are the pair sums, by radius and component", {
  skip_if_no_julia(circuitscape = FALSE)
  t <- flux_test_inputs()
  for (radius in c(1.5, 5, 12, Inf)) {
    k <- dp_kernel(t$circuit$env$template, radius, "pixels")
    inj <- dp_call("flux_injection", t$circuit$env$id, t$o, t$d, k$dr0, k$hw, k$rowmap)
    P <- flux_pair_weights(t$circuit, t$gi, t$o, t$d, radius)
    W <- sum(P)
    expect_equal(inj$b, (rowSums(P) - colSums(P)) / W, tolerance = 1e-10)
    expect_equal(inj$in_reach, W / (sum(t$o) * sum(t$d)), tolerance = 1e-12)
    # Balanced within each component
    expect_equal(as.vector(tapply(inj$b, t$gi$comp, sum)),
                 rep(0, length(unique(t$gi$comp))), tolerance = 1e-14)
  }
})

test_that("dp_flux matches a dense solve with a radius", {
  skip_if_no_julia(circuitscape = FALSE)
  t <- flux_test_inputs()
  P <- flux_pair_weights(t$circuit, t$gi, t$o, t$d, 5)
  want <- flux_exact_current(t$gi, (rowSums(P) - colSums(P)) / sum(P))
  r <- dp_flux(t$circuit, t$x$suitability, t$dest, radius = 5)
  expect_equal(dp_node_values(t$circuit, r$current), want, tolerance = 1e-8)
  expect_equal(attr(r, "in_reach"), sum(P) / (sum(t$o) * sum(t$d)), tolerance = 1e-12)
  expect_lt(attr(r, "in_reach"), 1)

  # A radius beyond the grid is the same as no limit
  far <- dp_flux(t$circuit, t$x$suitability, t$dest, radius = 100)
  inf <- dp_flux(t$circuit, t$x$suitability, t$dest)
  expect_equal(terra::values(far), terra::values(inf), tolerance = 1e-10)
  expect_equal(attr(far, "in_reach"), attr(inf, "in_reach"), tolerance = 1e-12)
})

test_that("dp_flux gives RMS cell values, bounded by the undirected map", {
  skip_if_no_julia(circuitscape = FALSE)
  t <- flux_test_inputs()
  P <- flux_pair_weights(t$circuit, t$gi, t$o, t$d, 5)
  W <- sum(P)
  b <- (rowSums(P) - colSums(P)) / W
  r <- dp_flux(t$circuit, t$x$suitability, t$dest, radius = 5, cell_value = "rms")
  rms <- dp_node_values(t$circuit, r$current)
  expect_equal(rms, flux_exact_current(t$gi, b, rms = TRUE), tolerance = 1e-8)
  # flow_x and flow_y don't depend on cell_value
  a <- dp_flux(t$circuit, t$x$suitability, t$dest, radius = 5)
  flows <- c("flow_x", "flow_y")
  expect_equal(terra::values(r[[flows]]), terra::values(a[[flows]]))
  expect_named(dp_flux(t$circuit, t$x$suitability, t$dest, radius = 5,
                       cell_value = "rms", normalize = FALSE, direction = FALSE),
               "current")

  # Exact undirected map (dp_omni with a destination): current^2 is half the
  # sum over a cell's links of sum_ij P_ij I_e(i, j)^2. The directional RMS
  # current squared, times W, is at most that.
  Pu <- P
  diag(Pu) <- 0
  undirected <- dipole_exact_cells(t$gi, (Pu + t(Pu)) / 2) / 2
  ok <- undirected > 1e-12 * max(undirected)
  ratio <- W * rms[ok]^2 / undirected[ok]
  expect_true(all(ratio <= 1 + 1e-8))

  # Close to 1 where all pairs flow the same way: origin in the west,
  # destination in the east
  tmpl <- terra::rast(nrows = 9, ncols = 24, xmin = 0, xmax = 24, ymin = 0, ymax = 9,
                      crs = "EPSG:5070")
  circuit <- dp_circuit(terra::setValues(tmpl, 1), resistance_is = "conductances",
                        flow_potential = FALSE)
  col <- (seq_len(terra::ncell(tmpl)) - 1) %% 24 + 1
  origin <- terra::setValues(tmpl, as.numeric(col <= 2))
  destination <- terra::setValues(tmpl, as.numeric(col >= 23))
  gi <- dipole_graph_info(circuit)
  o <- dp_node_values(circuit, origin)
  d <- dp_node_values(circuit, destination)
  P <- flux_pair_weights(circuit, gi, o, d, Inf)
  r <- dp_flux(circuit, origin, destination, cell_value = "rms")
  rms <- dp_node_values(circuit, r$current)
  undirected <- dipole_exact_cells(gi, (P + t(P)) / 2) / 2
  ratio <- sum(P) * rms^2 / undirected
  mid <- col[circuit$env$cells] %in% 8:17
  expect_true(all(ratio <= 1 + 1e-8))
  expect_gt(min(ratio[mid]), 0.9)
  expect_error(dp_flux(t$circuit, t$x$suitability, t$dest, cell_value = "sum"),
               "should be one of")
})

test_that("swapping origin and destination reverses the flow", {
  skip_if_no_julia(circuitscape = FALSE)
  t <- flux_test_inputs()
  a <- dp_flux(t$circuit, t$x$suitability, t$dest, radius = 6)
  b <- dp_flux(t$circuit, t$dest, t$x$suitability, radius = 6)
  expect_equal(terra::values(b$current), terra::values(a$current), tolerance = 1e-10)
  expect_equal(terra::values(b$flow_x), -terra::values(a$flow_x), tolerance = 1e-10)
  expect_equal(terra::values(b$flow_y), -terra::values(a$flow_y), tolerance = 1e-10)
  expect_equal(attr(b, "in_reach"), attr(a, "in_reach"), tolerance = 1e-12)
})

test_that("dp_flux gives the direction of flow", {
  skip_if_no_julia(circuitscape = FALSE)
  tmpl <- terra::rast(nrows = 15, ncols = 40, xmin = 0, xmax = 40, ymin = 0, ymax = 15,
                      crs = "EPSG:5070")
  cond <- terra::setValues(tmpl, 1)
  origin <- terra::setValues(tmpl, 0)
  destination <- origin
  origin[, 1:3] <- 1
  destination[, 38:40] <- 1
  r <- dp_flux(cond, origin, destination, resistance_is = "conductances")
  mid <- as.matrix(r[8, 10:30])
  expect_true(all(mid[, "flow_x"] > 0))
  expect_true(all(abs(mid[, "flow_y"]) < 1e-8))
  # Mirror symmetry about the middle row
  fy <- terra::as.matrix(r$flow_y, wide = TRUE)
  expect_equal(fy[1:7, ], -fy[15:9, ], tolerance = 1e-8)
  expect_named(dp_flux(cond, origin, destination, resistance_is = "conductances",
                       direction = FALSE),
               c("current", "flow_potential", "normalized_current"))
  expect_named(dp_flux(cond, origin, destination, resistance_is = "conductances",
                       normalize = FALSE), c("current", "flow_x", "flow_y"))
  # Out of reach
  expect_error(dp_flux(cond, origin, destination, radius = 20,
                       resistance_is = "conductances"), "within `radius`")
})

test_that("dp_flux weights each component by its origin-destination pairs", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)        # column 8 is NA
  origin <- terra::setValues(x$conductance, 0)
  destination <- origin
  origin[, 2:3] <- 1                          # left part
  origin[, 20:21] <- 1                        # right part
  destination[, 5:6] <- 1                     # left part
  destination[, 25:26] <- 1                   # right part
  destination[, 28:29] <- 1
  origin <- terra::mask(origin, x$conductance)
  destination <- terra::mask(destination, x$conductance)
  r <- dp_flux(x$conductance, origin, destination, resistance_is = "conductances")
  o <- terra::values(origin, mat = FALSE)
  d <- terra::values(destination, mat = FALSE)
  left <- (seq_len(terra::ncell(origin)) - 1) %% 31 < 7
  O <- c(sum(o[left], na.rm = TRUE), sum(o[!left], na.rm = TRUE))
  D <- c(sum(d[left], na.rm = TRUE), sum(d[!left], na.rm = TRUE))
  expect_equal(attr(r, "in_reach"), sum(O * D) / (sum(O) * sum(D)), tolerance = 1e-12)

  # Each part carries its share O_c D_c / W of the flow: on its own, the
  # left part's map is the same up to that factor
  o_left <- o
  o_left[!left & !is.na(o)] <- 0
  only_left <- dp_flux(x$conductance, terra::setValues(origin, o_left), destination,
                       resistance_is = "conductances")
  share <- O[1] * D[1] / sum(O * D)
  cur <- terra::values(r$current, mat = FALSE)
  cur_left <- terra::values(only_left$current, mat = FALSE)
  expect_equal(cur[left], share * cur_left[left], tolerance = 1e-8)
  expect_true(all(cur_left[!left & !is.na(cur_left)] == 0))
})

test_that("dp_flux's flow potential is the same flow on the uniform circuit", {
  skip_if_no_julia(circuitscape = FALSE)
  t <- flux_test_inputs()
  uniform <- terra::mask(t$x$conductance * 0 + 1, t$x$conductance)
  for (cv in c("absolute", "rms")) {
    r <- dp_flux(t$circuit, t$x$suitability, t$dest, radius = 6, cell_value = cv)
    u <- dp_flux(uniform, t$x$suitability, t$dest, radius = 6, cell_value = cv,
                 resistance_is = "conductances", normalize = FALSE)
    fp <- terra::values(r$flow_potential, mat = FALSE)
    expect_equal(fp, terra::values(u$current, mat = FALSE), tolerance = 1e-8)
    cur <- terra::values(r$current, mat = FALSE)
    expect_equal(terra::values(r$normalized_current, mat = FALSE),
                 ifelse(fp > 0, cur / fp, NA), tolerance = 1e-12)
  }
})
