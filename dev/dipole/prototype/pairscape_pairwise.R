# Pairscape vs pairwise Circuitscape on the same focal nodes.
#
# From the project root, in a terminal:
#
#   Rscript sandbox/pairscape_pairwise.R r && Rscript sandbox/pairscape_pairwise.R circuitscape
#
# For N focal nodes (drawn in proportion to suitability), compares:
#
#   circuitscape  cs_pairwise(): cumulative |current| over all N(N-1)/2 pairs,
#                 at N = 25, 50, 100, 200 (~17 minutes, nearly all at N = 200)
#   exact_sq      the exact sum over pairs of squared current, from N solves:
#                 for each link, sum_{i<j} (y_i - y_j)^2 = N sum y_i^2 - (sum y_i)^2,
#                 y_i being the link's current with node i as source
#   pairscape     32 draws, each injecting sum_{i<j} xi_ij (e_i - e_j) with xi
#                 standard normal: every pair, randomly weighted, in one solve;
#                 the mean squared current over draws estimates exact_sq
#
# exact_sq and pairscape also run at N = 500 and 1000, which pairwise
# Circuitscape can't reach in reasonable time. Maps are per-cell sums over a
# cell's links (squared methods shown as RMS). Agreement is Spearman's rho
# over cells with any current, plus median relative error for pairscape vs
# exact_sq. Results go to sandbox/connectivity_bench/pairwise/; reruns skip
# finished work.

library(terra)
source("sandbox/dipole.R")

what <- commandArgs(trailingOnly = TRUE)[1]
stopifnot(what %in% c("r", "circuitscape"))
n_cs <- c(25, 50, 100, 200)
n_all <- c(n_cs, 500, 1000)
n_draws <- 32

out_dir <- "sandbox/connectivity_bench/pairwise"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
tfile <- file.path(out_dir, "timings.csv")
done <- if (file.exists(tfile)) read.csv(tfile) else NULL
have <- function(method, n) !is.null(done) && any(done$method == method & done$nodes == n)
record <- function(method, n, part, seconds) {
      row <- data.frame(method = method, nodes = n, part = part, seconds = round(seconds, 2))
      write.table(row, tfile, sep = ",", row.names = FALSE, col.names = !file.exists(tfile),
                  append = file.exists(tfile))
      message(sprintf("%-12s N = %4d  %-14s %8.2f s", method, n, part, seconds))
}
tick <- function(expr) { t0 <- Sys.time(); force(expr); as.numeric(difftime(Sys.time(), t0, units = "secs")) }

suit <- rast("sandbox/connectivity_bench/suitability.tif")
conductance <- suit / global(suit, "mean", na.rm = TRUE)[[1]] + 1e-3

# Focal nodes: one fixed draw of 1000 distinct cells, in proportion to
# suitability; the first N are used at each N, so the node sets are nested
v <- values(suit, mat = FALSE)
ok <- which(!is.na(v) & v > 0.01)
set.seed(42)
node_cells <- ok[sample.int(length(ok), max(n_all), prob = v[ok])]
map_file <- function(method, n) file.path(out_dir, sprintf("%s_n%d.tif", method, n))


# Circuitscape -----------------------------------------------------------------

if (what == "circuitscape") {
      library(circuitscaper)
      cs_setup(threads = 1L)
      mid <- c(mean(as.vector(ext(suit))[1:2]), mean(as.vector(ext(suit))[3:4]))
      e <- ext(mid[1] - 0.5, mid[1] + 0.5, mid[2] - 0.5, mid[2] + 0.5)
      wc <- crop(conductance, e); wv <- which(!is.na(values(wc, mat = FALSE)))
      invisible(cs_pairwise(1 / wc, locations = xyFromCell(wc, wv[c(1, length(wv) %/% 2, length(wv))]),
                            solver = "cholmod"))
      for (n in n_cs) {
            if (have("circuitscape", n)) next
            out <- NULL
            secs <- tick(out <- cs_pairwise(1 / conductance, locations = xyFromCell(suit, node_cells[1:n]),
                                            solver = "cholmod"))
            writeRaster(out$current_map[["cumulative_current"]], map_file("circuitscape", n), overwrite = TRUE)
            record("circuitscape", n, "total", secs)
      }
}


# Exact squared and Pairscape ----------------------------------------------------

if (what == "r") {
      g <- NULL
      record("shared", 0, "graph+factor", tick(g <- dp_graph(conductance)))
      # Graph node index of each focal cell
      rc <- rowColFromCell(suit, node_cells)
      nodes <- g$id[rc]
      stopifnot(!anyNA(nodes))

      to_raster <- function(v, name) dp_raster(g, v, name)
      # Per-cell sum of squared link currents, for solutions V (nodes x columns)
      sq_cells <- function(V) {
            acc <- numeric(g$n)
            for (e in g$edges) {
                  x <- rowSums((e$g * (V[e$a, , drop = FALSE] - V[e$b, , drop = FALSE]))^2)
                  acc[e$a] <- acc[e$a] + x; acc[e$b] <- acc[e$b] + x
            }
            acc
      }

      for (n in n_all) {
            nd <- nodes[1:n]

            if (!have("exact_sq", n)) {
                  # Solutions for unit current from node i to node 1 (balanced, so
                  # the tiny ground floor carries nothing); pair differences are
                  # the same as for single-node injections
                  ts <- tl <- 0
                  sum_y2 <- lapply(g$edges, function(e) numeric(length(e$a)))
                  sum_y <- lapply(g$edges, function(e) numeric(length(e$a)))
                  for (ch in split(seq_len(n), ceiling(seq_len(n) / 50))) {
                        B <- matrix(0, g$n, length(ch))
                        B[cbind(nd[ch], seq_along(ch))] <- 1
                        B[nd[1], ] <- B[nd[1], ] - 1
                        V <- NULL
                        ts <- ts + tick(V <- as.matrix(Matrix::solve(g$fac, B, system = "A")))
                        tl <- tl + tick(for (k in seq_along(g$edges)) {
                              e <- g$edges[[k]]
                              Y <- e$g * (V[e$a, , drop = FALSE] - V[e$b, , drop = FALSE])
                              sum_y2[[k]] <- sum_y2[[k]] + rowSums(Y^2)
                              sum_y[[k]] <- sum_y[[k]] + rowSums(Y)
                        })
                  }
                  acc <- numeric(g$n)
                  tl <- tl + tick(for (k in seq_along(g$edges)) {
                        e <- g$edges[[k]]
                        x <- n * sum_y2[[k]] - sum_y[[k]]^2
                        acc[e$a] <- acc[e$a] + x; acc[e$b] <- acc[e$b] + x
                  })
                  writeRaster(to_raster(sqrt(pmax(acc, 0)), "exact_sq"), map_file("exact_sq", n), overwrite = TRUE)
                  record("exact_sq", n, "solves", ts)
                  record("exact_sq", n, "link_currents", tl)
            }

            if (!have("pairscape", n)) {
                  set.seed(n)
                  B <- NULL
                  tsamp <- tick({
                        B <- matrix(0, g$n, n_draws)
                        for (d in seq_len(n_draws)) {
                              Xi <- matrix(0, n, n)
                              Xi[upper.tri(Xi)] <- rnorm(n * (n - 1) / 2)
                              Xi <- Xi - t(Xi)            # b_i = sum_j xi_ij for j > i, minus for j < i
                              B[nd, d] <- rowSums(Xi)
                        }
                  })
                  V <- NULL
                  ts <- tick(V <- as.matrix(Matrix::solve(g$fac, B, system = "A")))
                  acc <- NULL
                  tl <- tick(acc <- sq_cells(V) / n_draws)
                  writeRaster(to_raster(sqrt(acc), "pairscape"), map_file("pairscape", n), overwrite = TRUE)
                  record("pairscape", n, "sampling", tsamp)
                  record("pairscape", n, "solves", ts)
                  record("pairscape", n, "link_currents", tl)
            }
      }
}


# Summary -----------------------------------------------------------------------

t <- read.csv(tfile)
tot <- aggregate(seconds ~ method + nodes, data = t[t$method != "shared", ], sum)
tot <- tot[order(tot$nodes, tot$method), ]
message("\nTimes (s; excluding the shared ", round(sum(t$seconds[t$method == "shared"]), 1),
        " s graph and factorization for the R methods):")
print(reshape(tot, idvar = "nodes", timevar = "method", direction = "wide"), row.names = FALSE)

cmp <- list()
load <- function(m, n) { f <- map_file(m, n); if (file.exists(f)) values(rast(f), mat = FALSE) }
for (n in n_all) {
      cs <- load("circuitscape", n); ex <- load("exact_sq", n); ps <- load("pairscape", n)
      rho <- function(a, b) {
            if (is.null(a) || is.null(b)) return(NA)
            k <- is.finite(a) & is.finite(b) & (a > 0 | b > 0)
            round(cor(a[k], b[k], method = "spearman"), 3)
      }
      err <- if (!is.null(ex) && !is.null(ps)) {
            k <- is.finite(ex) & is.finite(ps) & ex > 0
            round(median(abs(ps[k] / ex[k] - 1)), 3)
      } else NA
      cmp[[length(cmp) + 1]] <- data.frame(nodes = n, pairscape_vs_exact_sq = rho(ps, ex), median_rel_err = err,
                                           exact_sq_vs_circuitscape = rho(ex, cs),
                                           pairscape_vs_circuitscape = rho(ps, cs))
}
message("\nSpearman rho over cells with current (median relative error: pairscape vs exact_sq):")
print(do.call(rbind, cmp), row.names = FALSE)
