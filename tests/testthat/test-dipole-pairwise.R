# dp_pairwise(): random dipoles over focal nodes vs the exact N-solve sum
# (SPEC oracle 4), and the exact sum vs a dense brute force

focal_cells <- function(r, n, seed = 1) {
  withr::local_seed(seed)
  v <- terra::values(r, mat = FALSE)
  ok <- which(!is.na(v))
  sort(sample(ok, n))
}

test_that("exact pairwise matches a dense brute force, across components", {
  skip_if_no_julia()
  x <- dipole_test_grid(split = TRUE)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  cells <- focal_cells(x$conductance, 12)
  xy <- terra::xyFromCell(x$conductance, cells)
  ex <- dp_pairwise(circuit, xy, method = "exact")

  gi <- dipole_graph_info(circuit)
  node <- match(cells, circuit$env$cells)
  P <- matrix(0, length(gi$comp), length(gi$comp))
  P[node, node] <- 1
  P <- P * outer(gi$comp, gi$comp, "==")
  diag(P) <- 0
  # dipole_exact_cells sums over ordered pairs; dp_pairwise over unordered,
  # and reports sqrt(half the sum over a cell's links)
  want <- dipole_exact_cells(gi, P) / 4
  got <- dp_node_values(circuit, ex)^2
  expect_equal(got, want, tolerance = 1e-8)
  expect_equal(attr(ex, "n_pairs"), sum(P[upper.tri(P)]))
})

test_that("random pairwise is unbiased and matches exact (oracle 4)", {
  skip_if_no_julia()
  ref <- terra::rast(test_path("fixtures", "crop_R6_reference.tif"))
  circuit <- dp_circuit(ref$conductance, resistance_is = "conductances")
  for (n in c(25, 200)) {
    xy <- terra::xyFromCell(ref, focal_cells(ref$conductance, n, seed = n))
    ex <- terra::values(dp_pairwise(circuit, xy, method = "exact"), mat = FALSE)
    rd <- terra::values(dp_pairwise(circuit, xy, seed = 1), mat = FALSE)
    # 0.987-0.992 at 32 draws on this small crop (0.999 on the 0.73 M-cell
    # surface, whose values span a far wider range), rising with draws
    expect_gt(stats::cor(ex, rd, method = "spearman"), 0.98)
    rd <- terra::values(dp_pairwise(circuit, xy, n_draws = 512, seed = 1), mat = FALSE)
    expect_gt(stats::cor(ex, rd, method = "spearman"), 0.998)
  }
  xy <- terra::xyFromCell(ref, focal_cells(ref$conductance, 25))
  ex <- terra::values(dp_pairwise(circuit, xy, method = "exact"), mat = FALSE)^2
  rd <- terra::values(dp_pairwise(circuit, xy, n_draws = 2048, seed = 2), mat = FALSE)^2
  expect_equal(sum(rd), sum(ex), tolerance = 0.03)
  expect_lt(stats::median(abs(rd / ex - 1)), 0.06)
})

test_that("dp_pairwise takes rasters of IDs and checks its nodes", {
  skip_if_no_julia()
  x <- dipole_test_grid(split = TRUE)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  cells <- focal_cells(x$conductance, 6)
  ids <- terra::setValues(x$conductance, 0)
  ids[cells] <- c(4, 2, 6, 1, 5, 3)
  a <- dp_pairwise(circuit, ids, seed = 5, n_draws = 8)
  b <- dp_pairwise(circuit, terra::xyFromCell(ids, cells[c(4, 2, 6, 1, 5, 3)]),
                   seed = 5, n_draws = 8)
  expect_identical(terra::values(a), terra::values(b))
  expect_named(a, "current")
  expect_equal(rownames(attr(a, "halves")), "current")

  dup <- ids
  dup[cells[1:2]] <- 1
  expect_error(dp_pairwise(circuit, dup), "single cell")
  na_cell <- which(is.na(terra::values(x$conductance, mat = FALSE)))[1]
  bad <- ids
  bad[na_cell] <- 9
  expect_error(dp_pairwise(circuit, bad), "outside the circuit")
  # One node on each side of the split: no connected pairs
  left <- terra::cellFromRowCol(ids, 1, 1)
  right <- terra::cellFromRowCol(ids, 1, 31)
  expect_error(dp_pairwise(circuit, terra::xyFromCell(ids, c(left, right))),
               "No two focal nodes")
})
