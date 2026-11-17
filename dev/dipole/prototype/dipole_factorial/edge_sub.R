code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
# Same crop, 8 cells trimmed from every side, to measure study-area edge effects
suppressMessages(library(terra)); R <- 6L
s_full <- rast("../suitability.tif"); mean_full <- global(s_full, "mean", na.rm = TRUE)[[1]]
M <- as.matrix(s_full, wide = TRUE)[313:360, 345:392]; cond <- M / mean_full + 1e-3
out_file <- "edge_sub_R6.rds"
source(file.path(code_dir, "factorial.R"))
