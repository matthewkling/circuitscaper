code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
# Toy landscape: a barrier with a gap beyond the window radius.
suppressMessages(library(terra))
R <- 10L; nr <- nc <- 64
cond <- matrix(1, nr, nc); cond[31:33, 1:56] <- as.numeric(Sys.getenv("BARRIER", "1e-3"))          # barrier, gap at columns 57-64
M <- matrix(0, nr, nc); M[19:29, 1:48] <- 1; M[35:45, 1:48] <- 1
w <- as.vector(M); cond <- as.vector(cond)
out_file <- sprintf("toy_barrier_R10_%s.rds", Sys.getenv("BARRIER", "1e-3"))
source(file.path(code_dir, "factorial.R"))
