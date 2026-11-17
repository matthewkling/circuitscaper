# Exact check of the dipole estimator on a small grid.
#
#   Rscript sandbox/dipole_check.R   (from the project root; ~5 minutes)
#
# For every link e, the target is
#     T_e = sum over unordered pairs {i, j} of p_ij * I_e(i, j)^2
# where I_e(i, j) is the current on e when 1 unit enters at i and leaves at j,
# and p_ij is the pair weight the sampler draws from. On a small grid T is
# computed exactly from the dense inverse of the circuit matrix and compared
# with the estimate from the same functions the prototype uses (dipole.R),
# per cell (the sum over a cell's links, as the map reports it).
#
# If dp_sample() draws ordered pairs with probability p_ij / S, S = sum over
# ordered pairs, then each draw's expected cell sum of squared current is
# (2 M / S) * (cell sum of T_e) for M dipoles, so T is estimated by
# S / (2 M) times the mean over draws.

source("sandbox/dipole.R")
set.seed(42)

# A 40 x 40 grid of ~1.5 x 1.85 km cells, with a block of NA cells
nr <- 40; nc <- 40
tmpl <- rast(nrows = nr, ncols = nc, xmin = -110, xmax = -110 + nc / 60,
             ymin = 36, ymax = 36 + nr / 60, crs = "EPSG:4326")
smooth_field <- function(sd = 1) {
      r <- setValues(tmpl, rnorm(ncell(tmpl)))
      r <- focal(r, w = matrix(1, 7, 7), fun = mean, na.rm = TRUE)
      (r - global(r, "mean")[[1]]) / global(r, "sd")[[1]] * sd
}
conductance <- exp(smooth_field(1.5))              # ~ 1e-2 .. 1e2
conductance[cellFromRowColCombine(tmpl, 18:20, 5:30)] <- 1e-3   # a barrier with a gap
conductance[cellFromRowColCombine(tmpl, 30:33, 30:33)] <- NA    # a hole
suit <- 1 / (1 + exp(-2 * smooth_field(1.5)))       # 0 .. 1
suit[suit < 0.2] <- 0                                # some non-habitat
suit <- mask(suit, conductance)

g <- dp_graph(conductance)
g0 <- dp_graph(mask(setValues(conductance, 1), conductance))
w <- dp_node_values(g, suit); w[is.na(w)] <- 0
n <- g$n
cat("nodes:", n, " links:", sum(lengths(lapply(g$edges, `[[`, "g"))), "\n")


# Exact pair weights ------------------------------------------------------------

# Disk kernel as the sampler realizes it: a uniform point in a disk of radius R
# km, rounded to a cell offset. kappa = probability mass at each offset.
disk_kappa <- function(R) {
      lat_mid <- mean(as.vector(ext(tmpl))[3:4])
      px_x <- res(tmpl)[1] * 111.32 * cos(lat_mid * pi / 180)
      px_y <- res(tmpl)[2] * 110.57
      h <- min(px_x, px_y) / 60
      s <- seq(-R + h / 2, R - h / 2, by = h)
      xy <- expand.grid(x = s, y = s)
      xy <- xy[xy$x^2 + xy$y^2 <= R^2, ]
      off <- data.frame(dr = round(xy$y / px_y), dc = round(xy$x / px_x))
      tab <- aggregate(list(k = rep(1, nrow(off))), off, sum)
      tab$k <- tab$k / nrow(xy)
      tab
}
pair_weights <- function(R) {
      if (is.infinite(R)) {
            P <- outer(w, w)
      } else {
            kap <- disk_kappa(R)
            K <- matrix(0, 2 * nr + 1, 2 * nc + 1)
            K[cbind(kap$dr + nr + 1, kap$dc + nc + 1)] <- kap$k
            dr <- outer(g$node_r, g$node_r, function(a, b) b - a)
            dc <- outer(g$node_c, g$node_c, function(a, b) b - a)
            P <- outer(w, w) * matrix(K[cbind(as.vector(dr) + nr + 1, as.vector(dc) + nc + 1)], n, n)
      }
      diag(P) <- 0
      P
}


# Exact target, per cell --------------------------------------------------------

laplacian <- function(gr, ground_floor = 1e-12) {
      ea <- unlist(lapply(gr$edges, `[[`, "a")); eb <- unlist(lapply(gr$edges, `[[`, "b"))
      eg <- unlist(lapply(gr$edges, `[[`, "g"))
      L <- matrix(0, gr$n, gr$n)
      L[cbind(ea, eb)] <- -eg; L[cbind(eb, ea)] <- -eg
      diag(L) <- -rowSums(L) + ground_floor
      L
}
exact_cells <- function(gr, P) {
      X <- solve(laplacian(gr))
      C <- diag(rowSums(P)) - P              # sum_{i<j} P_ij (y_i - y_j)^2 = y' C y
      cell <- numeric(gr$n)
      for (e in gr$edges) {
            Y <- e$g * (X[e$a, , drop = FALSE] - X[e$b, , drop = FALSE])   # links x sources
            Te <- rowSums((Y %*% C) * Y)
            cell[e$a] <- cell[e$a] + Te
            cell[e$b] <- cell[e$b] + Te
      }
      cell
}


# Estimate vs exact, by number of draws -----------------------------------------

check <- function(R, M = 2000, draws = c(32, 128, 512, 2048, 8192)) {
      P <- pair_weights(R)
      S <- sum(P)
      ex <- exact_cells(g, P); ex0 <- exact_cells(g0, P)
      B <- dp_injections(g, w, max(draws), M, R)
      # Each row of the table uses the first k draws of the same set
      out <- lapply(draws, function(k) {
            ak <- rowSums(dp_accumulate(g, B[, 1:k, drop = FALSE], batch = 256))
            a0k <- rowSums(dp_accumulate(g0, B[, 1:k, drop = FALSE], batch = 256))
            est <- S / (2 * M) * ak / k
            est0 <- S / (2 * M) * a0k / k
            nrm <- sqrt(est / est0); nrm_ex <- sqrt(ex / ex0)
            ok <- ex > 0 & ex0 > 0
            data.frame(kernel = if (is.finite(R)) paste0("disk ", R, " km") else "no limit",
                       draws = k,
                       ratio_of_totals = round(sum(est[ok]) / sum(ex[ok]), 4),
                       median_rel_err = round(median(abs(est[ok] / ex[ok] - 1)), 4),
                       p95_rel_err = round(quantile(abs(est[ok] / ex[ok] - 1), 0.95), 4),
                       norm_median_rel_err = round(median(abs(nrm[ok] / nrm_ex[ok] - 1)), 4))
      })
      do.call(rbind, out)
}

res <- rbind(check(Inf), check(10))
rownames(res) <- NULL
print(res)
write.csv(res, "sandbox/connectivity_bench/dipole_check.csv", row.names = FALSE)
