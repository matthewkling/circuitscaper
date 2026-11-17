code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
# Exact factorial decomposition of the gap between the random-dipole method
# and Omniscape, on a 64 x 64 crop of the 2 km P. edulis surface.
#
# Factors, each computed exactly for every habitat target t and its sources s
# within the radius-R pixel circle (s != t):
#   agg     pairs: sum_s a_st f(x_st)    star: f(sum_s a_st x_st)   (x = unit s->t link current)
#   f       sq (reported as RMS)  |  abs
#   circuit whole crop  |  window (circuit clipped to the circle, as Omniscape)
#   weight  prod: a = w_s w_t  |  os: a = w_t w_s / sum_window w_s  (Omniscape)
#   fp      flow potential circuit: same shape as the current circuit, uniform
#           conductance  |  square: Omniscape's uniform (2R+1)^2 box (window only)
#   inj     abs maps with or without the half injected current at endpoints,
#           as Circuitscape's cell current includes
# Omniscape = star, abs, window, os, fp square, inj.  Random-dipole method =
# pairs, sq, whole, prod, fp same.
suppressMessages({ library(terra); library(Matrix); library(Rcpp) })
sourceCpp(file.path(code_dir, "pairs.cpp"))
if (!exists("M")) {
      args <- commandArgs(TRUE); R <- as.integer(args[1])
      s_full <- rast("../suitability.tif")
      mean_full <- global(s_full, "mean", na.rm = TRUE)[[1]]
      M <- as.matrix(s_full, wide = TRUE)[305:368, 337:400]
      cond <- M / mean_full + 1e-3
      out_file <- sprintf("factorial_R%d.rds", R)
}
nr <- nrow(M); nc <- ncol(M); n <- nr * nc
if (!exists("w")) { w <- as.vector(M); w[w < 0.01] <- 0 }
rr <- row(M)[]; cc <- col(M)[]                       # node k = column-major cell
# Global links, 8 neighbours, averaged conductances, diagonals / sqrt(2)
lk <- do.call(rbind, lapply(list(c(0, 1), c(1, 0), c(1, 1), c(1, -1)), function(o) {
      r2 <- rr + o[1]; c2 <- cc + o[2]; ok <- r2 >= 1 & r2 <= nr & c2 >= 1 & c2 <= nc
      a <- which(ok); b <- (c2[ok] - 1) * nr + r2[ok]
      f <- if (all(o != 0)) 1 / sqrt(2) else 1
      data.frame(a = a, b = b, g = (cond[a] + cond[b]) / 2 * f, g0 = f)
}))
nl <- nrow(lk)
lap <- function(a, b, g, m) { L <- sparseMatrix(i = c(a, b, a, b), j = c(b, a, a, b), x = c(-g, -g, g, g), dims = c(m, m)); L }

targets <- which(w > 0)
win_of <- function(t) which((rr - rr[t])^2 + (cc - cc[t])^2 <= R^2)
box_of <- function(t) which(abs(rr - rr[t]) <= R & abs(cc - cc[t]) <= R)

# Accumulators: link level, one column per combination
acc <- list()
add <- function(key, li, x) { if (is.null(acc[[key]])) acc[[key]] <<- numeric(nl); acc[[key]][li] <<- acc[[key]][li] + x }

# --- window circuits (and Omniscape's square fp box), Dirichlet ground at t --
local_currents <- function(cells, t, gcol, srcs) {
      li <- which(lk$a %in% cells & lk$b %in% cells)
      idx <- match(c(lk$a[li], lk$b[li]), cells); ia <- idx[seq_along(li)]; ib <- idx[-seq_along(li)]
      g <- lk[[gcol]][li]
      L <- as.matrix(lap(ia, ib, g, length(cells)))
      k <- match(t, cells); keep <- setdiff(seq_along(cells), k)
      E <- matrix(0, length(cells), length(srcs)); E[cbind(match(srcs, cells), seq_along(srcs))] <- 1
      V <- matrix(0, length(cells), length(srcs)); V[keep, ] <- solve(L[keep, keep], E[keep, , drop = FALSE])
      list(li = li, X = g * (V[ia, , drop = FALSE] - V[ib, , drop = FALSE]))
}
t0 <- Sys.time()
for (t in targets) {
      win <- win_of(t); srcs <- setdiff(win[w[win] > 0], t); if (!length(srcs)) next
      a <- list(prod = w[t] * w[srcs], os = w[t] * w[srcs] / sum(w[srcs]))
      for (circ in c("cur", "fpsame", "fpsquare")) {
            lc <- switch(circ, cur = local_currents(win, t, "g", srcs), fpsame = local_currents(win, t, "g0", srcs),
                         fpsquare = local_currents(box_of(t), t, "g0", srcs))
            for (wt in names(a)) {
                  st <- drop(lc$X %*% a[[wt]])
                  add(paste("pairs sq window", wt, circ), lc$li, drop(lc$X^2 %*% a[[wt]]))
                  add(paste("pairs abs window", wt, circ), lc$li, drop(abs(lc$X) %*% a[[wt]]))
                  add(paste("star sq window", wt, circ), lc$li, st^2)
                  add(paste("star abs window", wt, circ), lc$li, abs(st))
            }
      }
}
t_win <- difftime(Sys.time(), t0, units = "secs")

# --- whole crop: ground a reference node, y_s = L_r^-1 e_s -----------------
pl <- do.call(rbind, lapply(targets, function(t) { win <- win_of(t); s <- setdiff(win[w[win] > 0], t)
      if (!length(s)) return(NULL); data.frame(s = s, t = t, prod = w[t] * w[s], os = w[t] * w[s] / sum(w[s])) }))
t0 <- Sys.time()
for (circ in c("cur", "fpsame")) {
      g <- if (circ == "cur") lk$g else lk$g0
      L <- lap(lk$a, lk$b, g, n); ref <- n
      Y <- matrix(0, n, n); Y[-ref, ] <- as.matrix(solve(L[-ref, -ref], Diagonal(n)[-ref, ]))
      D <- g * (Y[lk$a, ] - Y[lk$b, ]); rm(Y)
      ps <- pair_sums(D, pl$s, pl$t, pl$prod, pl$os)
      add(paste("pairs sq whole prod", circ), 1:nl, ps[, 1]); add(paste("pairs abs whole prod", circ), 1:nl, ps[, 2])
      add(paste("pairs sq whole os", circ), 1:nl, ps[, 3]); add(paste("pairs abs whole os", circ), 1:nl, ps[, 4])
      for (wt in c("prod", "os")) {
            A <- sparseMatrix(i = c(pl$s, pl$t), j = c(match(pl$t, targets), match(pl$t, targets)),
                              x = c(pl[[wt]], -pl[[wt]]), dims = c(n, length(targets)))
            for (j0 in seq(1, length(targets), by = 300)) {
                  j <- j0:min(length(targets), j0 + 299)
                  X <- as.matrix(D %*% A[, j])
                  add(paste("star sq whole", wt, circ), 1:nl, rowSums(X^2)); add(paste("star abs whole", wt, circ), 1:nl, rowSums(abs(X)))
            }
      }
      rm(D); gc()
}
t_whole <- difftime(Sys.time(), t0, units = "secs")

# --- cell maps --------------------------------------------------------------
to_cell <- function(x, sq) { v <- numeric(n); v <- v + tabulate(lk$a, n) * 0
      cs <- numeric(n); cs <- cs + as.vector(tapply(c(x, x), factor(c(lk$a, lk$b), levels = 1:n), sum)); cs[is.na(cs)] <- 0
      if (sq) sqrt(cs / 2) else cs / 2 }
inj <- list(prod = numeric(n), os = numeric(n))
for (wt in c("prod", "os")) { x <- tapply(c(pl[[wt]], pl[[wt]]), factor(c(pl$s, pl$t), levels = 1:n), sum); x[is.na(x)] <- 0
      inj[[wt]] <- as.vector(x) / 2 }
maps <- list()
for (key in names(acc)) {
      p <- strsplit(key, " ")[[1]]; sq <- p[2] == "sq"
      v <- to_cell(acc[[key]], sq); maps[[key]] <- v
      if (!sq) maps[[paste(key, "inj")]] <- v + inj[[p[4]]]
}
saveRDS(list(maps = maps, w = w, nr = nr, nc = nc, R = R, t_win = t_win, t_whole = t_whole), out_file)
cat(sprintf("R = %d: %d targets, %d pairs; windows %.0f s, whole %.0f s; %d maps\n", R, length(targets), nrow(pl), t_win, t_whole, length(maps)))
