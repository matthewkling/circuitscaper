# Resolution invariance (same landscape on 2, 1, 0.5 km grids) and
# monotonicity in dispersal distance, settlement counted anywhere.
source("settlement.R"); source("landscape.R")
L <- synthetic_landscape()
run <- function(f, distance, settle_distance = 2) {
  res <- if (f == 1) L$res else terra::disagg(L$res, f)
  suit <- if (f == 1) L$suit else terra::disagg(L$suit, f)
  gr <- settle_graph(1 / res); gr$h <- gr$h / 1000          # km
  t <- terra::values(suit)[gr$cell, 1]
  P <- to_rast(gr, res, settle_prob(gr, settle_grounds(gr, t, distance, settle_distance)))
  if (f > 1) P <- terra::aggregate(P, f, mean)
  terra::values(P)[, 1]
}
core <- terra::values(L$suit)[, 1] > 0.8; matrixc <- terra::values(L$suit)[, 1] < 0.2
cat("Resolution, distance 10 km, settle_distance 2 km:\n")
base <- run(1, 10)
for (f in c(1, 2, 4)) {
  p <- if (f == 1) base else run(f, 10)
  cat(sprintf("  %-4s km: median P %.3f (core %.3f, matrix %.3f); max |diff| vs 2 km %.3f; median |diff| %.4f\n",
    2 / f, median(p), median(p[core]), median(p[matrixc]), max(abs(p - base)), median(abs(p - base))))
}
cat("Reach, 1 km grid:\n")
prev <- NULL
for (d in c(2.5, 5, 10, 20, 40)) {
  p <- run(2, d)
  cat(sprintf("  distance %4.1f km: median P %.3f (core %.3f, matrix %.3f)%s\n", d, median(p),
    median(p[core]), median(p[matrixc]),
    if (is.null(prev)) "" else sprintf("; cells lower than at the shorter distance: %d", sum(p < prev - 1e-12))))
  prev <- p
}
