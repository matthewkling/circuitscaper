code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
# Far-field diagnostic and scalable truncation variants (leak, tiles), exact,
# on the factorial crop. Compared against exact Omniscape from factorial_R*.rds.
source(file.path(code_dir, "setup.R"))   # defines R from args, grid, links lk, weights w, targets, win_of
pl <- do.call(rbind, lapply(targets, function(t) { win <- win_of(t); s <- setdiff(win[w[win] > 0], t)
      if (!length(s)) return(NULL); data.frame(s = s, t = t, prod = w[t] * w[s], os = w[t] * w[s] / sum(w[s])) }))
inj <- lapply(c(prod = "prod", os = "os"), function(wt) { x <- tapply(c(pl[[wt]], pl[[wt]]), factor(c(pl$s, pl$t), levels = 1:n), sum); x[is.na(x)] <- 0; as.vector(x) / 2 })
cellsum <- function(x) { v <- as.vector(tapply(c(x, x), factor(c(lk$a, lk$b), levels = 1:n), sum)); v[is.na(v)] <- 0; v / 2 }
fac <- readRDS(sprintf("factorial_R%d.rds", R))$maps
ref <- list(cur = fac[["star abs window os cur inj"]], fp = fac[["star abs window os fpsquare inj"]]); ref$norm <- ref$cur / ref$fp
hab <- w > 0
sp <- function(a, b) cor(a[hab], b[hab], method = "spearman")
report <- function(label, cur, fp) cat(sprintf("%-44s current %.3f | fp %.3f | normalized %.3f\n", label, sp(cur, ref$cur), sp(fp, ref$fp), sp(cur / fp, ref$norm)))
# pair sums on a circuit given by node set `cells` (NULL = whole), conductance column, optional leak length lam (px)
circuit_D <- function(gcol, lam = Inf, cells = NULL) {
      li <- if (is.null(cells)) seq_len(nl) else which(lk$a %in% cells & lk$b %in% cells)
      nodes <- if (is.null(cells)) seq_len(n) else cells
      ia <- match(lk$a[li], nodes); ib <- match(lk$b[li], nodes); g <- lk[[gcol]][li]; m <- length(nodes)
      L <- lap(ia, ib, g, m)
      cnode <- if (gcol == "g") cond[nodes] else rep(1, m)
      if (is.finite(lam)) { L <- L + Diagonal(m, cnode / lam^2); Y <- as.matrix(solve(L)) }
      else { ref <- m; Y <- matrix(0, m, m); Y[-ref, ] <- as.matrix(solve(L[-ref, -ref], Diagonal(m)[-ref, ])) }
      list(D = g * (Y[ia, , drop = FALSE] - Y[ib, , drop = FALSE]), li = li, nodes = nodes)
}
run_pairs <- function(C, sel = rep(TRUE, nrow(pl))) {
      p <- pl[sel, ]; ps <- pair_sums(C$D, match(p$s, C$nodes), match(p$t, C$nodes), p$prod, p$os)
      out <- matrix(0, nl, 4); out[C$li, ] <- ps; out
}
maps_from <- function(acc_cur, acc_fp, label) {
      for (k in 1:2) { wt <- c("prod", "os")[k]
            report(paste(label, "sq", wt), sqrt(cellsum(acc_cur[, 2 * k - 1])), sqrt(cellsum(acc_fp[, 2 * k - 1])))
            report(paste(label, "abs", wt), cellsum(acc_cur[, 2 * k]) + inj[[wt]], cellsum(acc_fp[, 2 * k]) + inj[[wt]]) }
}
cat(sprintf("== R = %d px ==\n", R))

# A. Far field: share of whole-circuit pair current on links farther than R from the target
mr <- (rr[lk$a] + rr[lk$b]) / 2; mc <- (cc[lk$a] + cc[lk$b]) / 2
for (gcol in c("g", "g0")) { C <- circuit_D(gcol)
      sp4 <- pair_split(C$D, pl$s, pl$t, pl$prod, mr, mc, rr, cc, R)
      cat(sprintf("far field (%s circuit): share of summed abs current beyond R of the target %.2f, of summed squared current %.2f\n",
                  if (gcol == "g") "resistance" else "uniform", sum(sp4[, 4]) / sum(sp4[, c(2, 4)]), sum(sp4[, 3]) / sum(sp4[, c(1, 3)])))
      if (gcol == "g") { far <- cellsum(sp4[, 4]); near <- cellsum(sp4[, 2])
            cat(sprintf("  per habitat cell, far-field share of abs current: median %.2f, 10-90%% %.2f-%.2f\n",
                        median((far / (far + near))[hab]), quantile((far / (far + near))[hab], .1), quantile((far / (far + near))[hab], .9))) }
}
rm(C); gc()

# B. Leak: every node grounded with conductance c_i / lam^2 (decay length ~lam px)
for (k in c(0.5, 1, 2)) { lam <- k * R
      maps_from(run_pairs(circuit_D("g", lam)), run_pairs(circuit_D("g0", lam)), sprintf("leak lambda=%.1fR", k)) }

# C. Tiles: square cores of side `core`, circuit = core + buffer R on each side;
#    pairs assigned to the tile holding their target
for (core in c(R, 2 * R)) {
      acc_c <- acc_f <- matrix(0, nl, 4)
      t_tile <- paste((rr[pl$t] - 1) %/% core, (cc[pl$t] - 1) %/% core)
      for (tl in unique(t_tile)) { sel <- t_tile == tl
            i0 <- min(rr[pl$t[sel]]) - 1 - ((min(rr[pl$t[sel]]) - 1) %% core); j0 <- min(cc[pl$t[sel]]) - 1 - ((min(cc[pl$t[sel]]) - 1) %% core)
            cells <- which(rr > i0 - R & rr <= i0 + core + R & cc > j0 - R & cc <= j0 + core + R)
            acc_c <- acc_c + run_pairs(circuit_D("g", cells = cells), sel)
            acc_f <- acc_f + run_pairs(circuit_D("g0", cells = cells), sel) }
      maps_from(acc_c, acc_f, sprintf("tiles core=%dpx buffer=R", core))
}
