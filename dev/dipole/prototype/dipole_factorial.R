# Exact factorial decomposition of the random-dipole method vs Omniscape, and
# toy-landscape tests of window truncation, on a 64 x 64 crop of the 2 km
# P. edulis surface.
#
#   Rscript sandbox/dipole_factorial.R [step ...]
#
# Run from the project root. Code is in sandbox/dipole_factorial/; outputs
# go to sandbox/connectivity_bench/factorial/. Steps (default: all, in order):
#   factorial  every combination of pairs/stars, squared/absolute,
#              whole/window circuit, product/Omniscape weights, and flow
#              potential circuit, exactly, at R = 6 and 12 px  (~15 min)
#   analyze    Spearman of each combination against exact Omniscape
#   validate   exact Omniscape reimplementation vs real os_run (needs
#              sandbox/dipole_factorial_omniscape.R to have been run)
#   variants   far-field share; leak and tile truncation  (~15 min)
#   toys       barrier, weak-spot and corridor toys; study-area edge test
#   figures    crop maps and barrier-toy figure
# Needs Rcpp and a C++ compiler.
steps <- commandArgs(TRUE)
if (!length(steps)) steps <- c("factorial", "analyze", "validate", "variants", "toys", "figures")
code_dir <- normalizePath("sandbox/dipole_factorial")
out_dir <- "sandbox/connectivity_bench/factorial"; dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
run <- function(script, args = character(), env = character()) {
      message(sprintf("== %s %s", script, paste(args, collapse = " ")))
      st <- system2("Rscript", c(file.path(code_dir, script), args), env = c(sprintf("CODE_DIR=%s", code_dir), env))
      if (st != 0) stop(script, " failed")
}
owd <- setwd(out_dir); on.exit(setwd(owd))
for (s in steps) switch(s,
      factorial = for (R in c(6, 12)) run("factorial.R", R),
      analyze   = for (R in c(6, 12)) run("analyze.R", R),
      validate  = run("validate.R"),
      variants  = for (R in c(6, 12)) run("variants.R", R),
      toys      = { for (b in c("1e-3", "1e-6")) run("toy_barrier.R", env = sprintf("BARRIER=%s", b))
                    run("toy_weak.R"); run("toy_corridor.R"); run("toy_an3.R")
                    run("edge_sub.R"); run("edge_an.R") },
      figures   = { run("fig.R"); run("toy_fig.R") },
      stop("unknown step ", s))
