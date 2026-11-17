code_dir <- Sys.getenv("CODE_DIR", "../../dipole_factorial")
# Barrier with a weak spot inside the window radius and the real gap beyond it
R <- 10L; nr <- nc <- 64
cond <- matrix(1, nr, nc); cond[31:33, 1:56] <- 1e-6; cond[31:33, 22:25] <- 1e-3
M <- matrix(0, nr, nc); M[19:29, 1:48] <- 1; M[35:45, 1:48] <- 1
w <- as.vector(M); cond <- as.vector(cond); out_file <- "toy_weak_R10.rds"
source(file.path(code_dir, "factorial.R"))
