# Tiling test for the dipole method with a local (disk) kernel.
#
#   Rscript sandbox/dipole_tiling.R   (from the project root; ~4 minutes)
#
# Pairs are split among 3 x 3 core tiles by their first endpoint. Each tile is
# solved on its core plus a buffer, and the tiles' squared currents are summed
# into one map. To isolate truncation error from sampling noise, the reference
# solves exactly the same per-tile dipole sets on the full, untruncated grid:
# the only difference between the two is the tile edge.

source("sandbox/dipole.R")
tk <- function(t0) as.numeric(difftime(Sys.time(), t0, units = "secs"))
set.seed(7)

R <- 50                       # kernel radius, km
buffers_km <- c(50, 100, 150)
n_draws <- 16
n_dipoles <- 1e5              # per draw, over the whole domain
n_tiles <- 3                  # per side

suit <- rast("sandbox/connectivity_bench/suitability.tif")
cond <- suit / global(suit, "mean", na.rm = TRUE)[[1]] + 1e-3
uni <- mask(setValues(cond, 1), cond)

t0 <- Sys.time(); g <- dp_graph(cond); g0 <- dp_graph(uni); t_full_graphs <- tk(t0)
w <- dp_node_values(g, suit); w[is.na(w) | w < 0] <- 0
hab <- w > 0.01

lat_mid <- mean(as.vector(ext(suit))[3:4])
px_x <- res(suit)[1] * 111.32 * cos(lat_mid * pi / 180)
px_y <- res(suit)[2] * 110.57

# Core tiles in row/column ranges
brk <- function(n) round(seq(0, n, length.out = n_tiles + 1))
rb <- brk(g$nr); cb <- brk(g$nc)
tiles <- expand.grid(ti = seq_len(n_tiles), tj = seq_len(n_tiles))
tiles$r0 <- rb[tiles$ti] + 1; tiles$r1 <- rb[tiles$ti + 1]
tiles$c0 <- cb[tiles$tj] + 1; tiles$c1 <- cb[tiles$tj + 1]
tile_of <- function(i) {
      ti <- findInterval(g$node_r[i] - 1, rb[-1]) + 1   # rows rb[k]+1..rb[k+1] -> k
      tj <- findInterval(g$node_c[i] - 1, cb[-1]) + 1
      (tj - 1) * n_tiles + ti
}

# Dipoles: one set per draw over the whole domain, with signs and tiles
draws <- lapply(seq_len(n_draws), function(d) {
      x <- dp_sample(g, w, n_dipoles, R)
      x$s <- sample(c(-1, 1), n_dipoles, replace = TRUE)
      x$tile <- tile_of(x$i)
      x
})

# Keep only pairs whose partner lies within the narrowest window, so every
# configuration and the reference use identical pairs
bmin_r <- ceiling(min(buffers_km) / px_y); bmin_c <- ceiling(min(buffers_km) / px_x)
inside <- function(x, tl, br, bc) {
      r <- g$node_r[x$j]; cc <- g$node_c[x$j]
      r >= tl$r0 - br & r <= tl$r1 + br & cc >= tl$c0 - bc & cc <= tl$c1 + bc
}
dropped <- 0
draws <- lapply(draws, function(x) {
      keep <- logical(length(x$i))
      for (t in seq_len(nrow(tiles))) {
            k <- x$tile == t
            keep[k] <- inside(lapply(x, `[`, k), tiles[t, ], bmin_r, bmin_c)
      }
      dropped <<- dropped + sum(!keep)
      lapply(x, `[`, keep)
})
cat(sprintf("Dipoles dropped (partner beyond narrowest window): %d of %d\n", dropped, n_draws * n_dipoles))

# Injection matrix for one tile's pairs, with node ids mapped by `map`
tile_B <- function(t, n, map = identity) {
      i <- j <- s <- d <- NULL
      for (k in seq_len(n_draws)) {
            x <- draws[[k]]; sel <- x$tile == t
            i <- c(i, map(x$i[sel])); j <- c(j, map(x$j[sel])); s <- c(s, x$s[sel])
            d <- c(d, rep(k, sum(sel)))
      }
      as.matrix(Matrix::sparseMatrix(i = c(i, j), j = c(d, d), x = c(s, -s), dims = c(n, n_draws)))
}
acc_sum <- function(gr, B) rowSums(dp_accumulate(gr, B, batch = 8))


# Reference: each tile's pairs solved separately on the full grid ----------------

t0 <- Sys.time()
ref <- ref0 <- numeric(g$n)
for (t in seq_len(nrow(tiles))) {
      B <- tile_B(t, g$n)
      ref <- ref + acc_sum(g, B); ref0 <- ref0 + acc_sum(g0, B)
}
t_ref <- tk(t0)

# The usual untiled estimate from the same dipoles (all tiles in one injection).
# It differs from the reference only by the random cross terms between tiles'
# pairs, so this is a lower bound on sampling noise, not the full amount.
t0 <- Sys.time()
Ball <- Reduce(`+`, lapply(seq_len(nrow(tiles)), function(t) tile_B(t, g$n)))
unt <- acc_sum(g, Ball); unt0 <- acc_sum(g0, Ball)
t_untiled <- tk(t0) + t_full_graphs
rm(Ball)

err <- function(x, y, m = hab) {
      e <- abs(x[m] / y[m] - 1)
      c(median = median(e), p95 = unname(quantile(e, 0.95)), p99 = unname(quantile(e, 0.99)), max = max(e))
}
rows <- list(cbind(data.frame(config = "untiled vs reference (cross-tile terms)", seconds = round(t_untiled)),
                   t(round(err(unt, ref), 4)),
                   norm = t(round(err(sqrt(unt / unt0), sqrt(ref / ref0)), 4))))


# Tiled ---------------------------------------------------------------------------

maps <- list()
for (bk in buffers_km) {
      br <- ceiling(bk / px_y); bc <- ceiling(bk / px_x)
      t0 <- Sys.time()
      til <- til0 <- numeric(g$n)
      for (t in seq_len(nrow(tiles))) {
            tl <- tiles[t, ]
            wr <- max(1, tl$r0 - br):min(g$nr, tl$r1 + br)
            wc <- max(1, tl$c0 - bc):min(g$nc, tl$c1 + bc)
            sub <- cond[wr, wc, drop = FALSE]
            gs <- dp_graph(sub); gs0 <- dp_graph(mask(setValues(sub, 1), sub))
            stopifnot(gs$nr == length(wr), gs$nc == length(wc))
            glob <- g$id[cbind(gs$node_r + wr[1] - 1, gs$node_c + wc[1] - 1)]
            loc <- integer(g$n); loc[glob] <- seq_len(gs$n)
            B <- tile_B(t, gs$n, map = function(v) loc[v])
            til[glob] <- til[glob] + acc_sum(gs, B)
            til0[glob] <- til0[glob] + acc_sum(gs0, B)
      }
      secs <- tk(t0)
      rows[[length(rows) + 1]] <- cbind(
            data.frame(config = sprintf("tiled, buffer %d km (%d x %d cells)", bk, bc, br), seconds = round(secs)),
            t(round(err(til, ref), 4)),
            norm = t(round(err(sqrt(til / til0), sqrt(ref / ref0)), 4)))
      maps[[as.character(bk)]] <- dp_raster(g, abs(til / ref - 1), sprintf("buffer_%dkm", bk))
}

res <- do.call(rbind, rows)
print(res, row.names = FALSE)
write.csv(res, "sandbox/connectivity_bench/tile_results.csv", row.names = FALSE)

# Where truncation error falls, with tile edges
png("sandbox/connectivity_bench/tile_error.png", width = 2400, height = 900, res = 150)
par(mfrow = c(1, length(maps)), mar = c(1, 1, 3, 5))
for (nm in names(maps)) {
      m <- mask(maps[[nm]], suit > 0.01, maskvalues = c(0, NA))
      plot(log10(m + 1e-6), range = c(-4, 0), col = hcl.colors(100, "inferno"), axes = FALSE,
           main = sprintf("Buffer %s km: log10 |tiled / reference - 1|", nm))
      xs <- xFromCol(suit, cb[-c(1, length(cb))] + 0.5); ys <- yFromRow(suit, rb[-c(1, length(rb))] + 0.5)
      abline(v = xs, h = ys, col = "cyan", lty = 2)
}
dev.off()
