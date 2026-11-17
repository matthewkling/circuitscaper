code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
# Two habitat blocks 8 cells apart across poor matrix, joined by a 2-cell corridor
R <- 10L; nr <- nc <- 64
cond <- matrix(0.02, nr, nc); cond[, 1:28] <- 1; cond[, 37:64] <- 1; cond[31:32, 29:36] <- 1
M <- matrix(0, nr, nc); M[12:52, 9:28] <- 1; M[12:52, 37:56] <- 1
w <- as.vector(M); cond <- as.vector(cond); out_file <- "toy_corridor_R10.rds"
source(file.path(code_dir, "factorial.R"))
