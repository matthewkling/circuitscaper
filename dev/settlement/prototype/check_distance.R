# Does `distance` give the mean distance travelled before death, in uniform
# terrain of conductance 1 with no habitat, on grids of different spacing?
source("settlement.R")
for (cfg in list(c(h = 1, d = 5), c(h = 1, d = 10), c(h = 0.5, d = 10), c(h = 0.25, d = 10), c(h = 2, d = 10))) {
  h <- cfg[["h"]]; d <- cfg[["d"]]
  half <- ceiling(8 * d / h)        # wide enough that the edge hardly matters
  N <- 2 * half + 1
  cond <- terra::rast(nrows = N, ncols = N, xmin = 0, xmax = N * h, ymin = 0, ymax = N * h, vals = 1)
  gr <- settle_graph(cond)
  k <- settle_grounds(gr, rep(0, gr$n), d, 1)
  i <- which(gr$row == half + 1 & gr$col == half + 1)
  v <- as.numeric(solve(gr$L + Diagonal(x = k$death), sparseVector(1, i, gr$n)))
  died <- k$death * v
  r <- h * sqrt((gr$row - gr$row[i])^2 + (gr$col - gr$col[i])^2)
  cat(sprintf("h %.2f, distance %4.1f: mass %.4f, mean distance at death %.2f (ratio %.3f)\n",
              h, d, sum(died), sum(r * died) / sum(died), sum(r * died) / sum(died) / d))
}
