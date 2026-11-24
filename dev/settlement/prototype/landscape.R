# Synthetic test landscape: smooth suitability and resistance on a 2 km grid
# (60 x 60 = 120 km), UTM metres; resistance about 1 in good habitat.
synthetic_landscape <- function(seed = 1, nr = 60, res_km = 2) {
  set.seed(seed)
  tmpl <- terra::rast(nrows = nr, ncols = nr, xmin = 0, xmax = nr * res_km * 1000,
                      ymin = 0, ymax = nr * res_km * 1000, crs = "EPSG:32611")
  smooth <- function() {
    r <- terra::setValues(tmpl, rnorm(terra::ncell(tmpl)))
    for (i in 1:3) r <- terra::focal(r, matrix(1, 5, 5), mean, na.rm = TRUE)
    (r - terra::global(r, "mean")[[1]]) / terra::global(r, "sd")[[1]]
  }
  suit <- 1 / (1 + exp(-2.5 * (smooth() - 0.3)))
  res <- exp(3 * (1 - suit) + 0.8 * smooth())
  list(suit = suit, res = res)
}
