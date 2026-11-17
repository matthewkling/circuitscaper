# Cross-era (range-shift) connectivity three ways, against the app's model.
#
#   Rscript sandbox/pairscape_crossera.R
#
# Run from the project root, after sandbox/export_crossera.R. Compares, on
# the 2 km P. edulis present and future surfaces:
#   advanced       the app's cs_advanced model: present habitat as current
#                  sources, future habitat as ground conductances, loss "none"
#   net_flux       oriented: present habitat injects and future habitat
#                  withdraws fixed amounts (each summing to 1); one solve.
#                  Net movement of the range; pairing drops out, so a kernel
#                  could only change the cell totals
#   gross_100km,   random-sign Pairscape pairs, present habitat to future
#   gross_nolimit  habitat within 100 km or anywhere; dispersal-limited
#                  pathway use, both directions counted, no direction
# Also reports how much of the advanced-mode current leaves through the
# 1e-6-per-cell "no loss" floor instead of the target grounds.
# Writes crossera_maps.tif and crossera_maps.png to
# sandbox/connectivity_bench/crossera/.
source("sandbox/dipole.R")
dir <- "sandbox/connectivity_bench/crossera"
tk <- function(t0) round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
s <- rast(file.path(dir, "surfaces.tif")); adv <- rast(file.path(dir, "advanced.tif"))
hst <- s$hist; fut <- s$fut

# As the app: NA (outside the data) counts as zero suitability, so every cell
# is a node; conductance sqrt(hist * fut) scaled to mean 1, plus 1e-3
z <- function(r) { r[is.na(r)] <- 0; r }
suit <- sqrt(z(hst) * z(fut))
cond <- suit / global(suit, "mean")$mean + 1e-3
norm1 <- function(r) { r <- z(r); r / global(r, "sum")$sum }
src <- norm1(hst); dst <- norm1(fut)

# Where the advanced-mode current exits: target grounds vs the "none" loss floor
V <- values(adv$voltage, mat = FALSE); dv <- values(dst, mat = FALSE)
i_dest <- sum(dv * V, na.rm = TRUE); i_leak <- sum(1e-6 * V, na.rm = TRUE)
cat(sprintf("Advanced mode: %.3f of the current exits at target grounds, %.3f through the 1e-6 'no loss' floor (total %.3f)\n",
            i_dest, i_leak, i_dest + i_leak))

t0 <- Sys.time(); g <- dp_graph(cond); cat("graph + factor:", tk(t0), "s\n")
node <- function(r) dp_node_values(g, r)
ws <- node(src); wd <- node(dst)

# Per-cell Circuitscape-style current: half the sum of |link current| over a cell's links
abs_cells <- function(V) {
      acc <- numeric(g$n)
      for (e in g$edges) { x <- abs(e$g * (V[e$a] - V[e$b])); acc[e$a] <- acc[e$a] + x; acc[e$b] <- acc[e$b] + x }
      acc / 2
}

# 1. Oriented net flux: fixed sources (present) and fixed sinks (future), one solve
t0 <- Sys.time()
Vn <- as.vector(Matrix::solve(g$fac, matrix(ws - wd, ncol = 1), system = "A"))
net <- abs_cells(Vn); t_net <- tk(t0)

# 2-3. Gross pathways: random-sign pairs, i in proportion to present habitat,
# j to future habitat within the kernel
lat_mid <- mean(as.vector(ext(cond))[3:4])
px_x <- res(cond)[1] * 111.32 * cos(lat_mid * pi / 180); px_y <- res(cond)[2] * 110.57
sample2 <- function(m, radius) {
      wmax <- max(wd); oi <- oj <- integer(m); got <- 0
      while (got < m) {
            k <- as.integer(min(4e6, 4 * (m - got) + 1000))
            i <- sample.int(g$n, k, replace = TRUE, prob = ws)
            if (is.finite(radius)) {
                  rr <- radius * sqrt(runif(k)); th <- runif(k, 0, 2 * pi)
                  r2 <- g$node_r[i] + round(rr * sin(th) / px_y); c2 <- g$node_c[i] + round(rr * cos(th) / px_x)
                  inb <- r2 >= 1 & r2 <= g$nr & c2 >= 1 & c2 <= g$nc
                  j <- rep(NA_integer_, k); j[inb] <- g$id[cbind(r2[inb], c2[inb])]
                  ok <- which(!is.na(j) & j != i); ok <- ok[runif(length(ok)) < wd[j[ok]] / wmax]
            } else {
                  j <- sample.int(g$n, k, replace = TRUE, prob = wd); ok <- which(j != i)
            }
            take <- head(ok, m - got)
            oi[got + seq_along(take)] <- i[take]; oj[got + seq_along(take)] <- j[take]; got <- got + length(take)
      }
      list(i = oi, j = oj)
}
gross <- function(radius, nd = 32, m = 1e5) {
      B <- matrix(0, g$n, nd)
      for (d in seq_len(nd)) {
            x <- sample2(m, radius); sg <- sample(c(-1, 1), m, TRUE)
            agg <- rowsum(c(sg, -sg), c(x$i, x$j)); B[as.integer(rownames(agg)), d] <- agg[, 1]
      }
      a <- dp_accumulate(g, B)
      list(rms = sqrt(rowSums(a) / nd / 2), halves = dp_halves(sqrt(a[, 1]), sqrt(a[, 2]), ws > 0 | wd > 0))
}
set.seed(1)
t0 <- Sys.time(); g100 <- gross(100); t_g100 <- tk(t0)
t0 <- Sys.time(); ginf <- gross(Inf); t_ginf <- tk(t0)
cat(sprintf("net flux %.1f s; gross 100 km %.1f s (halves rel diff %.2f); gross no limit %.1f s (halves %.2f)\n",
            t_net, t_g100, g100$halves[2], t_ginf, ginf$halves[2]))

maps <- c(adv$current_flow, dp_raster(g, net, "net_flux"), dp_raster(g, g100$rms, "gross_100km"),
          dp_raster(g, ginf$rms, "gross_nolimit"))
names(maps)[1] <- "advanced"
writeRaster(maps, file.path(dir, "crossera_maps.tif"), overwrite = TRUE)

v <- values(maps); hab <- (values(z(hst), mat = FALSE) > 0.01 | values(z(fut), mat = FALSE) > 0.01)
rho <- cor(v[hab, ], method = "spearman", use = "pairwise.complete.obs")
cat("\nSpearman rho over present or future habitat cells:\n"); print(round(rho, 3))

rs <- function(r) { v <- values(r, mat = FALSE); ok <- is.finite(v) & v > 0; v[ok] <- rank(v[ok]) / sum(ok); v[!ok] <- NA; setValues(r, v) }
ttl <- c(advanced = "App advanced mode (grounded targets)", net_flux = "Net flux (fixed sinks, oriented)",
         gross_100km = "Gross pathways, 100 km reach", gross_nolimit = "Gross pathways, no distance limit")
png(file.path(dir, "crossera_maps.png"), width = 2000, height = 2000, res = 150)
par(mfrow = c(2, 2), mar = c(1, 1, 3, 1))
for (nm in names(maps)) plot(rs(maps[[nm]]), col = hcl.colors(100, "viridis"), legend = FALSE, axes = FALSE, main = ttl[nm])
dev.off()
