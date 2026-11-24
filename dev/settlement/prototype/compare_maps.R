# Settlement maps beside the dipole maps on the example landscape.
suppressMessages(devtools::load_all("../../..", quiet = TRUE))
source("settlement.R")
r0 <- terra::rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
r <- r0; terra::crs(r) <- ""; terra::ext(r) <- c(0, 50, 0, 50)
gr <- settle_graph(1 / r)
t <- as.numeric(terra::values(r)[gr$cell, 1] == 1)
habitat <- terra::ifel(r0 == 1, 1, 0)
home <- readRDS("home_sd2.rds"); gross <- readRDS("gross.rds")
k <- settle_grounds(gr, t, 10, 2)
net <- net_flow(gr, k, t)
iso <- dp_isolation(r0, 15, habitat, normalize = FALSE, seed = 1, progress = FALSE)
omni <- dp_omni(r0, 15, habitat, normalize = FALSE, seed = 1, progress = FALSE)
maps <- c(log10(r0), habitat,
          to_rast(gr, r0, home$P), to_rast(gr, r0, home$Pa),
          -log10(iso$resistance),
          log10(to_rast(gr, r0, gross$m64)), log10(to_rast(gr, r0, net)), log10(omni$current))
names(maps) <- c("resistance (log10)", "habitat",
                 "settle anywhere", "settle beyond 2-cell site",
                 "dp_isolation: -log10 resistance",
                 "gross flow, 64 draws (log10)", "net flow (log10)", "dp_omni current (log10)")
png("compare_maps.png", width = 1400, height = 720, res = 110)
terra::plot(maps, nr = 2, nc = 4, mar = c(1.5, 1.5, 2, 4), axes = FALSE)
dev.off()
v <- terra::values(maps)
sp <- function(a, b) cor(v[, a], v[, b], method = "spearman", use = "complete.obs")
cat(sprintf("rho: settle anywhere vs dp_isolation %.2f; settle away vs dp_isolation %.2f\n", sp(3, 5), sp(4, 5)))
cat(sprintf("rho: gross flow vs dp_omni current %.2f; net flow vs dp_omni %.2f; gross vs net %.2f\n", sp(6, 8), sp(7, 8), sp(6, 7)))
hab <- v[, 2] == 1
cat(sprintf("rho within habitat: settle away vs dp_isolation %.2f; within matrix %.2f\n",
  cor(v[hab, 4], v[hab, 5], method = "spearman", use = "complete.obs"),
  cor(v[!hab, 4], v[!hab, 5], method = "spearman", use = "complete.obs")))
