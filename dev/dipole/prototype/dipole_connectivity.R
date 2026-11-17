# Within-era connectivity by superposed random dipoles
#
#   Rscript sandbox/dipole_connectivity.R
#
# Run from the project root. Uses sandbox/connectivity_bench/suitability.tif
# (from sandbox/export_surface.R) if present, otherwise builds the P. edulis
# surface with the core. Compares against the Omniscape and pairwise outputs
# in that folder, where they exist.
#
# Method. Pairwise cumulative current sums |current| over node pairs solved
# one at a time. This estimates the squared-current analogue,
#
#     sum over pairs (i, j) of  w_i * w_j * k(d_ij) * I_e(i, j)^2   for every link e,
#
# with suitability w at both ends and a distance kernel k (a disk of
# radius_km; Inf for no distance limit). Each draw superposes many unit
# dipoles (+1 at i, -1 at j) with random signs into one injection: cross-pair
# terms cancel in expectation, so the mean squared link current over draws
# is that sum, up to a constant. The circuit is the same in every draw, so it
# is factored once and all draws are solved against the factor. Maps show
# RMS current per cell.
#
# Normalization mirrors Omniscape's: the same dipoles on a uniform-
# conductance circuit give a flow potential, and current / flow potential
# separates channelled from diffuse and impeded flow. Reusing the dipoles
# cancels much of the sampling noise in the ratio.
#
# Tuning (2 km, default box, against a 256-draw reference): accuracy improves
# with dipoles per draw up to ~1e5-3e5, then mainly with draws. 32 draws of
# 1e5 dipoles gives ~6% median error in current and ~3% in the normalized
# layer. The halves check (odd vs even draws) reports this without a reference.

library(terra)
source("sandbox/dipole.R")

out_dir <- "sandbox/connectivity_bench"
radius_km <- c(50, Inf)
n_draws <- 32
n_dipoles <- 1e5
set.seed(1)

suit_file <- file.path(out_dir, "suitability.tif")
if (file.exists(suit_file)) {
      suit <- rast(suit_file)
} else {
      source("scripts/load_core.R")
      result <- ts_model(ts_settings(species = "Pinus edulis", clim_agg = 2), ts_data("data"))
      suit <- setNames(ts_layer(result, time = "historical")[[1]], "suitability")
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      writeRaster(suit, suit_file, overwrite = TRUE)
}

# As server/connectivity.R: resistance there is 1 / (this)
conductance <- suit / global(suit, "mean", na.rm = TRUE)[[1]] + 1e-3

t0 <- Sys.time()
g <- dp_graph(conductance)
g0 <- dp_graph(mask(setValues(conductance, 1), conductance))
message(sprintf("Graphs and factorizations: %.1f s", difftime(Sys.time(), t0, units = "secs")))

maps <- list()
for (radius in radius_km) {
      label <- if (is.finite(radius)) sprintf("dipole_r%gkm", radius) else "dipole_global"
      r <- dp_connectivity(suit, conductance, radius, n_draws, n_dipoles, g = g, g0 = g0)
      s <- attr(r, "seconds"); h <- attr(r, "halves")
      message(sprintf("%-14s sampling %.1f s, solves %.1f s | halves (habitat): current rho %.3f, rel. diff %.2f; normalized rho %.3f, rel. diff %.2f",
                      label, s["sampling"], s["solves"], h["current", 1], h["current", 2],
                      h["normalized", 1], h["normalized", 2]))
      writeRaster(r, file.path(out_dir, paste0(label, ".tif")), overwrite = TRUE)
      maps[[label]] <- r
}


# Comparison ------------------------------------------------------------------

v <- function(x) values(x, mat = FALSE)
hab <- v(suit) > 0.01 & !is.na(v(suit))
rho <- function(x, y) round(cor(v(x)[hab], v(y)[hab], method = "spearman", use = "complete.obs"), 3)

os_file <- file.path(out_dir, "omniscape_r50km_layers.tif")
pw_file <- file.path(out_dir, "pairwise_n200_cholmod.tif")
os <- if (file.exists(os_file)) rast(os_file)
pw <- if (file.exists(pw_file)) rast(pw_file)
r50 <- maps[["dipole_r50km"]]; gl <- maps[["dipole_global"]]

if (!is.null(os)) {
      message("Spearman rho within habitat, dipole r = 50 km vs Omniscape r = 50 km: ",
              "current ", rho(r50$current, os$cumulative_current),
              ", flow potential ", rho(r50$flow_potential, os$flow_potential),
              ", normalized ", rho(r50$normalized, os$normalized_current))
}
if (!is.null(pw)) message("Spearman rho within habitat, dipole (no limit) vs pairwise n = 200: ",
                          rho(gl$current, pw))

# Ranks rather than values: the methods' units differ, and ranks show
# whether they put the same places high and low
rank_stretch <- function(r) {
      x <- v(r); ok <- is.finite(x)
      x[ok] <- rank(x[ok]) / sum(ok); x[!ok] <- NA
      setValues(r, x)
}
panels <- Filter(Negate(is.null), list(
      if (!is.null(os)) list(os$cumulative_current, "Omniscape r = 50 km: cumulative current"),
      list(r50$current, "Dipole r = 50 km: RMS current"),
      if (!is.null(os)) list(os$normalized_current, "Omniscape r = 50 km: normalized current"),
      list(r50$normalized, "Dipole r = 50 km: normalized"),
      if (!is.null(pw)) list(pw, "Pairwise, 200 nodes: cumulative current"),
      list(gl$current, "Dipole, no distance limit: RMS current")))
png(file.path(out_dir, "dipole_vs_references.png"), width = 2000, height = 900 * ceiling(length(panels) / 2), res = 150)
par(mfrow = c(ceiling(length(panels) / 2), 2), mar = c(1, 1, 3, 1))
for (p in panels) plot(rank_stretch(p[[1]]), col = hcl.colors(100, "viridis"), legend = FALSE,
                       axes = FALSE, main = p[[2]])
dev.off()
message("Wrote ", out_dir)
