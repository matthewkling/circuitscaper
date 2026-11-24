# Gross flow from random-sign monopoles: convergence to the exact sum over
# sources of squared current, on the example landscape.
source("settlement.R")
r <- terra::rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
terra::crs(r) <- ""; terra::ext(r) <- c(0, 50, 0, 50)
gr <- settle_graph(1 / r)
t <- as.numeric(terra::values(r)[gr$cell, 1] == 1)
k <- settle_grounds(gr, t, 10, 2)
ex <- gross_flow_exact(gr, k, t)
draws <- gross_flow_draws(gr, k, t, 1024, seed = 1)
for (nd in c(16, 64, 256, 1024)) {
  m <- rowMeans(draws[, 1:nd, drop = FALSE])
  se <- apply(draws[, 1:nd, drop = FALSE], 1, sd) / sqrt(nd)
  cat(sprintf("%4d draws: median |rel error| %.3f (90%% %.3f); median rel SE %.3f; rho %.4f; bias of total %+.3f\n",
    nd, median(abs(m / ex - 1)), quantile(abs(m / ex - 1), .9), median(se / m),
    cor(m, ex, method = "spearman"), sum(m) / sum(ex) - 1))
}
saveRDS(list(ex = ex, m64 = rowMeans(draws[, 1:64])), "gross.rds")
