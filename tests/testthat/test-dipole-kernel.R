# Disk kernels as exact sets of cell offsets (no Julia needed)

# The kernel's offsets from each source row, as a data frame (row, dr, dc)
kernel_offsets <- function(k, rows) {
  do.call(rbind, lapply(rows, function(r) {
    hw <- k$hw[, k$rowmap[r]]
    do.call(rbind, lapply(seq_along(hw), function(d) {
      if (hw[d] < 0) return(NULL)
      data.frame(row = r, dr = k$dr0 + d - 1, dc = -hw[d]:hw[d])
    }))
  }))
}

# Brute force: all offsets within the grid whose distance is <= radius
brute_offsets <- function(template, radius, dist) {
  nr <- terra::nrow(template)
  nc <- terra::ncol(template)
  do.call(rbind, lapply(seq_len(nr), function(r) {
    g <- expand.grid(dr = (1 - r):(nr - r), dc = -(nc - 1):(nc - 1))
    g <- g[dist(r, g$dr, g$dc) <= radius, ]
    if (nrow(g)) data.frame(row = r, dr = g$dr, dc = g$dc)
  }))
}

same_offsets <- function(a, b) {
  key <- function(x) sort(paste(x$row, x$dr, x$dc))
  expect_identical(key(a), key(b))
}

test_that("pixel kernels are the cells with dr^2 + dc^2 <= radius^2", {
  tmpl <- terra::rast(nrows = 30, ncols = 30)
  for (radius in c(1, 1.5, 2, 5, 6, 7.3)) {
    k <- dp_kernel(tmpl, radius, "pixels")
    off <- kernel_offsets(k, 1)
    expect_true(all(off$dr^2 + off$dc^2 <= radius^2))
    R <- ceiling(radius)
    all <- expand.grid(dr = -R:R, dc = -R:R)
    expect_equal(nrow(off), sum(all$dr^2 + all$dc^2 <= radius^2))
  }
  expect_equal(nrow(kernel_offsets(dp_kernel(tmpl, 6, "pixels"), 1)), 113)
  expect_equal(nrow(dp_kernel(tmpl, Inf)$hw), 0)
})

test_that("km kernels on lon/lat grids use great-circle distance by row", {
  tmpl <- terra::rast(nrows = 40, ncols = 30, xmin = -110, xmax = -109.5,
                      ymin = 60, ymax = 60 + 40 / 60, crs = "EPSG:4326")
  lat <- terra::yFromRow(tmpl, 1:40) * pi / 180
  dist <- function(r, dr, dc) {
    haversine_km(lat[r], lat[r + dr], dc * terra::xres(tmpl) * pi / 180)
  }
  for (radius in c(3, 7.5, 12)) {
    k <- dp_kernel(tmpl, radius, "km")
    expect_equal(ncol(k$hw), 40)
    same_offsets(kernel_offsets(k, 1:40), brute_offsets(tmpl, radius, dist))
  }
  # Cells narrow towards the pole, so northern rows reach more columns
  k <- dp_kernel(tmpl, 10, "km")
  mid <- 1 - k$dr0
  expect_gt(k$hw[mid, 1], k$hw[mid, 40])
})

test_that("km kernels on projected grids use map units", {
  tmpl <- terra::rast(nrows = 30, ncols = 25, xmin = 0, xmax = 25 * 800,
                      ymin = 0, ymax = 30 * 1000, crs = "EPSG:5070")
  dist <- function(r, dr, dc) sqrt((dr * 1000)^2 + (dc * 800)^2) / 1000
  for (radius in c(1, 2.5, 6)) {
    k <- dp_kernel(tmpl, radius, "km")
    want <- brute_offsets(tmpl, radius, dist)
    got <- kernel_offsets(k, 1:30)
    got <- got[got$row + got$dr >= 1 & got$row + got$dr <= 30, ]
    same_offsets(got, want)
  }
})

test_that("kernels reject bad radii", {
  tmpl <- terra::rast(nrows = 10, ncols = 10)
  expect_error(dp_kernel(tmpl, 0.5, "pixels"), "smaller than a cell")
  expect_error(dp_kernel(tmpl, -1, "pixels"), "positive")
  expect_error(dp_kernel(tmpl, NA_real_, "pixels"), "positive")
  nocrs <- terra::rast(nrows = 10, ncols = 10, crs = "")
  expect_error(suppressWarnings(dp_kernel(nocrs, 5, "km")), "coordinate reference")
})
