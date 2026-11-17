code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
R <- as.integer(commandArgs(TRUE)[1]); x <- readRDS(sprintf("factorial_R%d.rds", R)); m <- x$maps
rr <- rep(1:x$nr, x$nc); cc <- rep(1:x$nc, each = x$nr)
hab <- x$w > 0; inner <- hab & rr > R & rr <= x$nr - R & cc > R & cc <= x$nc - R
cfg <- expand.grid(agg = c("pairs", "star"), f = c("sq", "abs"), circ = c("whole", "window"), wt = c("prod", "os"),
                   fp = c("same", "square"), inj = c(FALSE, TRUE), stringsAsFactors = FALSE)
cfg <- cfg[!(cfg$circ == "whole" & cfg$fp == "square") & !(cfg$f == "sq" & cfg$inj), ]
key <- function(r, circ) paste(c(r$agg, r$f, r$circ, r$wt, circ, if (r$inj) "inj"), collapse = " ")
lay <- function(r) { cur <- m[[key(r, "cur")]]; fp <- m[[key(r, paste0("fp", r$fp))]]; list(cur = cur, fp = fp, norm = cur / fp) }
ref <- lay(list(agg = "star", f = "abs", circ = "window", wt = "os", fp = "square", inj = TRUE))
sp <- function(a, b, k) cor(a[k], b[k], method = "spearman")
res <- cbind(cfg, t(sapply(seq_len(nrow(cfg)), function(i) { l <- lay(cfg[i, ])
      c(cur = sp(l$cur, ref$cur, hab), fp = sp(l$fp, ref$fp, hab), norm = sp(l$norm, ref$norm, hab),
        cur_in = sp(l$cur, ref$cur, inner), norm_in = sp(l$norm, ref$norm, inner)) })))
res <- res[order(-res$norm), ]; res[, 7:11] <- round(res[, 7:11], 3)
write.csv(res, sprintf("factorial_R%d.csv", R), row.names = FALSE)
cat(sprintf("R = %d px, %d habitat cells (%d interior); Spearman vs exact Omniscape (star abs window os square inj)\n", R, sum(hab), sum(inner)))
print(res, row.names = FALSE)
