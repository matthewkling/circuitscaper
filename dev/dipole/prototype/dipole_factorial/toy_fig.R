code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
cf <- list("Omniscape" = c("star abs window os cur inj", "star abs window os fpsquare inj"),
           "Random dipoles (squared, whole)" = c("pairs sq whole prod cur", "pairs sq whole prod fpsame"),
           "Absolute, whole circuit" = c("pairs abs whole prod cur inj", "pairs abs whole prod fpsame inj"),
           "Absolute, window" = c("pairs abs window prod cur inj", "pairs abs window prod fpsame inj"))
m <- readRDS("toy_barrier_R10_1e-6.rds")$maps; hab <- matrix(0, 64, 64); hab[19:29, 1:48] <- 1; hab[35:45, 1:48] <- 1
png("toy_barrier_normalized.png", width = 2400, height = 680, res = 150); par(mfrow = c(1, 5), mar = c(0.5, 0.5, 3, 0.5))
img <- function(z, main, zl, col = hcl.colors(100, "viridis")) { image(t(z)[, 64:1], col = col, zlim = zl, axes = FALSE, main = main, cex.main = 0.9); box() }
lay <- matrix(1, 64, 64); lay[31:33, 1:56] <- 0
img(lay + hab, "Habitat (yellow), barrier (dark),\ngap at right end", c(0, 2))
for (nm in names(cf)) img(matrix(log10(pmin(pmax(m[[cf[[nm]][1]]] / m[[cf[[nm]][2]]], 0.1), 10)), 64),
                          paste0(nm, "\nnormalized current (log10, -1 to 1)"), c(-1, 1), hcl.colors(100, "Blue-Red 3"))
dev.off()
