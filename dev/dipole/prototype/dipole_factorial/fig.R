code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
x <- readRDS("factorial_R12.rds"); m <- x$maps; nr <- x$nr
cfgs <- list(
  "Omniscape (exact)" = c("star abs window os cur inj", "star abs window os fpsquare inj"),
  "Random dipoles: squared, whole" = c("pairs sq whole prod cur", "pairs sq whole prod fpsame"),
  "Absolute, whole (Cauchy target)" = c("pairs abs whole prod cur inj", "pairs abs whole prod fpsame inj"),
  "Absolute, window" = c("pairs abs window prod cur inj", "pairs abs window prod fpsame inj"))
rk <- function(v) { r <- rank(v) / length(v); matrix(r, nr) }
png("factorial_maps_R12.png", width = 2400, height = 1300, res = 150)
par(mfrow = c(2, 5), mar = c(0.5, 0.5, 2.5, 0.5))
img <- function(z, main) { image(t(z)[, nrow(z):1], col = hcl.colors(100, "viridis"), axes = FALSE, main = main, cex.main = 0.9); box() }
img(matrix(x$w, nr), "Source strength")
for (nm in names(cfgs)) img(rk(m[[cfgs[[nm]][1]]]), paste("Current:", nm))
img(matrix(cond_dummy <- x$w, nr) * 0 + NA, "")
for (nm in names(cfgs)) img(rk(m[[cfgs[[nm]][1]]] / m[[cfgs[[nm]][2]]]), paste("Normalized:", nm))
dev.off()
