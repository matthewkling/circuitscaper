code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
cf <- list("Omniscape" = c("star abs window os cur inj", "star abs window os fpsquare inj"),
           "Random dipoles (sq, whole)" = c("pairs sq whole prod cur", "pairs sq whole prod fpsame"),
           "Absolute, whole" = c("pairs abs whole prod cur inj", "pairs abs whole prod fpsame inj"),
           "Absolute, window, circular fp" = c("pairs abs window prod cur inj", "pairs abs window prod fpsame inj"))
rr <- rep(1:64, 64); cc <- rep(1:64, each = 64)
f2 <- function(nm) if (grepl("sq", nm)) function(v) v^2 else identity
m <- readRDS("toy_weak_R10.rds")$maps
weak <- rr %in% 31:33 & cc %in% 22:25; gap <- rr %in% 31:33 & cc >= 57; bar <- rr %in% 31:33 & cc <= 56 & !weak
cat("WEAK SPOT (barrier 1e-6, weak spot 1e-3 at cols 22-25, gap at cols 57-64)\n")
for (nm in names(cf)) { cur <- m[[cf[[nm]][1]]]; nn <- cur / m[[cf[[nm]][2]]]; f <- f2(nm); tot <- sum(f(cur[weak | gap | bar]))
  cat(sprintf("  %-30s share of barrier-row current: weak spot %.2f, gap %.2f | normalized: weak spot %5.2f, gap %5.2f, rest of barrier (median) %.3f\n",
      nm, sum(f(cur[weak])) / tot, sum(f(cur[gap])) / tot, mean(nn[weak]), mean(nn[gap]), median(nn[bar]))) }
m <- readRDS("toy_corridor_R10.rds")$maps
cor_c <- rr %in% 31:32 & cc %in% 29:36; mat <- !(rr %in% 31:32) & cc %in% 29:36 & rr %in% 12:52
cat("CORRIDOR (blocks 8 cells apart across 0.02 matrix, corridor 2 cells wide)\n")
for (nm in names(cf)) { cur <- m[[cf[[nm]][1]]]; nn <- cur / m[[cf[[nm]][2]]]; f <- f2(nm)
  cat(sprintf("  %-30s corridor share of gap-crossing current %.2f | normalized: corridor %5.2f, matrix between blocks %.3f\n",
      nm, sum(f(cur[cor_c])) / sum(f(cur[cor_c | mat])), mean(nn[cor_c]), mean(nn[mat]))) }
