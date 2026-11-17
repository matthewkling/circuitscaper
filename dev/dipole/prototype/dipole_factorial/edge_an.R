code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
big <- readRDS("factorial_R6.rds"); sub <- readRDS("edge_sub_R6.rds")
idx_big <- as.vector(outer(9:56, (9:56 - 1) * 64, "+"))            # sub cell k (column-major) -> big cell
rs <- rep(1:48, 48); cs <- rep(1:48, each = 48); dedge <- pmin(rs, 49 - rs, cs, 49 - cs)   # 1 = outermost ring
hab <- sub$w > 0
cf <- list("Omniscape" = c("star abs window os cur inj", "star abs window os fpsquare inj"),
           "Random dipoles (sq, whole)" = c("pairs sq whole prod cur", "pairs sq whole prod fpsame"),
           "Absolute, whole" = c("pairs abs whole prod cur inj", "pairs abs whole prod fpsame inj"),
           "Absolute, window, circular fp" = c("pairs abs window prod cur inj", "pairs abs window prod fpsame inj"))
bands <- list("1-3" = 1:3, "4-6" = 4:6, "7-9" = 7:9, "10-12" = 10:12, "13+" = 13:24)
cat("Median |log ratio| of normalized current, trimmed study area vs full crop, habitat cells, by distance (cells) from the trimmed edge; R = 6\n")
cat(sprintf("%-31s %s\n", "", paste(sprintf("%7s", names(bands)), collapse = "")))
for (nm in names(cf)) { a <- sub$maps[[cf[[nm]][1]]] / sub$maps[[cf[[nm]][2]]]; b <- (big$maps[[cf[[nm]][1]]] / big$maps[[cf[[nm]][2]]])[idx_big]
  d <- abs(log(a / b)); cat(sprintf("%-31s %s\n", nm, paste(sprintf("%7.3f", sapply(bands, function(k) median(d[hab & dedge %in% k]))), collapse = ""))) }
cat("Same for current:\n")
for (nm in names(cf)) { a <- sub$maps[[cf[[nm]][1]]]; b <- big$maps[[cf[[nm]][1]]][idx_big]
  d <- abs(log(a / b)); cat(sprintf("%-31s %s\n", nm, paste(sprintf("%7.3f", sapply(bands, function(k) median(d[hab & dedge %in% k]))), collapse = ""))) }
