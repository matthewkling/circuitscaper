code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
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
