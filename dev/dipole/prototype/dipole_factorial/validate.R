code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
library(terra)
d <- "."
cs <- as.vector(as.matrix(rast(file.path(d, "crop_suitability.tif")), wide = TRUE))
for (R in c(6, 12)) {
  x <- readRDS(sprintf("factorial_R%d.rds", R)); m <- x$maps
  stopifnot(max(abs(cs - (function(){ s <- rast("../suitability.tif"); as.vector(as.matrix(s, wide=TRUE)[305:368, 337:400]) })())) < 1e-6)
  os <- rast(file.path(d, sprintf("omniscape_R%d.tif", R)))
  real <- lapply(names(os), function(nm) as.vector(as.matrix(os[[nm]], wide = TRUE))); names(real) <- names(os)
  mine <- list(cumulative_current = m[["star abs window os cur inj"]], flow_potential = m[["star abs window os fpsquare inj"]])
  mine$normalized_current <- mine$cumulative_current / mine$flow_potential
  mine0 <- list(cumulative_current = m[["star abs window os cur"]], flow_potential = m[["star abs window os fpsquare"]])
  hab <- x$w > 0
  for (nm in names(mine)) { a <- mine[[nm]]; b <- real[[nm]]; k <- is.finite(a) & is.finite(b) & b > 0 & a > 0
    r <- a[k] / b[k]
    cat(sprintf("R=%2d %-19s spearman %.5f (habitat %.5f) | ratio mine/real median %.5f, 1%%-99%% %.4f-%.4f\n", R, nm,
        cor(a[k], b[k], method = "spearman"), cor(a[k & hab], b[k & hab], method = "spearman"), median(r), quantile(r, .01), quantile(r, .99))) }
  for (nm in names(mine0)) { a <- mine0[[nm]]; b <- real[[nm]]; k <- is.finite(a) & is.finite(b) & b > 0 & a > 0
    cat(sprintf("     (no injection) %-19s ratio median %.5f, 1%%-99%% %.4f-%.4f\n", nm, median(a[k]/b[k]), quantile(a[k]/b[k], .01), quantile(a[k]/b[k], .99))) }
}
x <- readRDS("factorial_R6.rds"); os <- rast(file.path(d, "omniscape_R6.tif"))
b <- as.vector(as.matrix(os[["cumulative_current"]], wide = TRUE)); a <- x$maps[["star abs window os cur inj"]]
rr <- rep(1:64, 64); cc <- rep(1:64, each = 64); off <- which(abs(a / b - 1) > 0.005)
cat(length(off), "cells off by >0.5%; distance to crop edge:", table(pmin(rr[off] - 1, 64 - rr[off], cc[off] - 1, 64 - cc[off]))[1:6], "\n")
print(head(cbind(r = rr[off], c = cc[off], mine = a[off], real = b[off], w = x$w[off])))
