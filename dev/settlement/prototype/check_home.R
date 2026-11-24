# Settling at home, and settlement rules, on the package's example landscape
# (50 x 50 cells, resistance 1 / 10 / 100 / 1000; habitat = resistance 1).
source("settlement.R")
r <- terra::rast(system.file("extdata/resistance.tif", package = "circuitscaper"))
terra::crs(r) <- ""; terra::ext(r) <- c(0, 50, 0, 50)     # plain pixel units
gr <- settle_graph(1 / r)
t <- as.numeric(terra::values(r)[gr$cell, 1] == 1)
hab <- t == 1
D <- 10
for (sd in c(1, 2, 5)) {
  k <- settle_grounds(gr, t, D, sd)
  P <- settle_prob(gr, k)
  t0 <- Sys.time(); Pa <- settle_prob_away(gr, k, site = 2); el <- as.numeric(Sys.time() - t0, units = "secs")
  cat(sprintf("settle_distance %g: P median habitat %.3f, matrix %.3f | away (beyond 2-cell site) habitat %.3f, matrix %.3f | rho(P, away): habitat %.2f, matrix %.2f, all %.2f  [%.0f s]\n",
    sd, median(P[hab]), median(P[!hab]), median(Pa[hab]), median(Pa[!hab]),
    cor(P[hab], Pa[hab], method = "spearman"), cor(P[!hab], Pa[!hab], method = "spearman"),
    cor(P, Pa, method = "spearman"), el))
  saveRDS(list(P = P, Pa = Pa), sprintf("home_sd%g.rds", sd))
}
Pc <- settle_prob_contact(gr, t, D)
P05 <- settle_prob(gr, settle_grounds(gr, t, D, 0.5))
cat(sprintf("first contact: matrix median %.3f; rho with settle_distance 0.5 (matrix cells) %.3f\n",
  median(Pc[!hab]), cor(Pc[!hab], P05[!hab], method = "spearman")))
