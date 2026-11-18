## Alternative hex logo: the package name drawn by current flow. (Writes man/figures/logo.png,
## like hex-logo.R; run whichever one is in use.)
##
## The title's glyph outlines are rasterized into a synthetic resistance surface, as low-resistance
## letters set in a noisy higher-resistance landscape, and dp_pairwise() runs current through it
## between the centers of the landscape's top and bottom edges. The logo is that current, with the
## magma palette on a square-root scale, so the word is drawn by the flow it channels rather than
## overlaid as text.
##
## Run from the package root, with a working Julia (see cs_setup()). The title uses Helvetica Neue
## Condensed Bold (macOS), falling back to Helvetica Neue Bold or Nimbus Sans Narrow Bold if it
## isn't installed; its size is set from its measured width, so it fills the same share of the
## hexagon whichever face is used. The landscape noise is seeded and the current is exact, so
## reruns give the same logo.
##
## As in hex-logo.R, the plot is rendered with ragg and masked to the hexagon with magick, giving a
## transparent background outside it.

library(ggplot2)
# load once per session: reloading resets circuitscaper's Julia state, so Julia would be set up
# again on every run
if(!isNamespaceLoaded("circuitscaper")) devtools::load_all()

out_file <- tempfile(fileext = ".png")   # full-resolution render; use_logo() resizes it
dpi <- 600

# design parameters ---------------------------------------------------------------------------

R <- 300                                 # hexagon circumradius, landscape cells
pad <- 40                                # landscape beyond the hexagon on each side, cells
inch_per_R <- 1.176                      # print scale: inches of logo per R; sets the
# sticker size (sqrt(3) x 2 R) that sizes below assume

# title
title <- "circuit   \n   scaper"
title_width <- 0.75                      # share of the hexagon's width the title spans
title_y <- 0                             # height of the title's vertical center, units of R
font_choices <- list(c("Helvetica Neue", "Condensed Bold"),
                     c("Helvetica Neue", "Bold"),
                     c("Nimbus Sans Narrow", "Bold"))

# resistance: background = bg_resistance * exp(bg_contrast * standardized multiscale noise);
# letters = letter_factor * the background's `letter_quantile` quantile, so they stay the best
# corridors however strong the background contrast is
noise_scales <- c(60, 20, 6)             # background noise feature sizes, cells,
noise_weights <- c(1, 0.6, 0.3)          # and their relative amplitudes
bg_resistance <- 10
bg_contrast <- 1.25
letter_quantile <- 0.001
letter_factor <- 0.001
seed <- 48 # (77 also good)         # background noise seed

# palette: magma on sqrt(current), stretched between these quantiles of the cells in the hexagon
col <- list(border = "black", current = viridisLite::magma(256))
stretch <- c(0, 0.999)

# title font ----------------------------------------------------------------------------------

fonts <- systemfonts::system_fonts()
font <- NULL
for(fc in font_choices){
      i <- which(fonts$family == fc[1] & fonts$style == fc[2])
      if(length(i)){
            font <- list(path = fonts$path[i[1]], index = fonts$index[i[1]])
            message("title font: ", fc[1], " ", fc[2])
            break
      }
}
if(is.null(font)) stop("none of the title fonts in `font_choices` is installed")

# title polygons ------------------------------------------------------------------------------

# glyph outlines, laid out by shape_string() and scaled so the title spans `title_width` of the
# hexagon, centered on (0, title_y * R) in landscape cells
em <- 1000
shape <- systemfonts::shape_string(title, path = font$path, index = font$index,
                                   size = em, res = 72, align = "center",
                                   lineheight = 0.6)$shape
shape <- shape[shape$glyph != "\n", ]   # the newline maps to the font's .notdef glyph (a box)

outline <- systemfonts::glyph_outline(shape$index, path = font$path, index = font$index,
                                      size = em)
outline$x <- outline$x + shape$x_offset[outline$glyph]
outline$y <- outline$y + shape$y_offset[outline$glyph]
scale <- title_width * sqrt(3) * R / diff(range(outline$x))
outline$x <- (outline$x - mean(range(outline$x))) * scale
outline$y <- (outline$y - mean(range(outline$y))) * scale + title_y * R

# one polygon per contour; a cell is inside a letter if an odd number of contours cover it,
# which leaves the counters of letters like "a", "e" and "p" open
outline$id <- as.integer(factor(paste(outline$glyph, outline$contour)))
outline$part <- 1
contours <- terra::vect(as.matrix(outline[, c("id", "part", "x", "y")]), type = "polygons",
                        crs = "local")

# landscape -----------------------------------------------------------------------------------

half_w <- ceiling(sqrt(3) / 2 * R) + pad
half_h <- R + pad
cells <- terra::rast(xmin = -half_w, xmax = half_w, ymin = -half_h, ymax = half_h,
                     resolution = 1, crs = "local")

# letter coverage: each cell's share inside a letter, from a finer rasterization, so edge cells
# follow the true outline rather than a staircase
supersample <- 16
fine <- terra::rast(terra::ext(cells), resolution = 1 / supersample, crs = "local")
letters <- terra::rasterize(contours, fine, fun = "count", background = 0) %% 2 == 1
letters <- terra::aggregate(letters, supersample, fun = "mean")

# standardized Gaussian noise with features of about `scale` cells: white noise on a coarse
# grid, interpolated to the landscape grid
set.seed(seed)
standardize <- function(z) (z - terra::global(z, "mean")[[1]]) / terra::global(z, "sd")[[1]]
noise <- function(scale){
      coarse <- terra::rast(terra::extend(terra::ext(cells), 2 * scale),
                            resolution = scale, crs = "local")
      terra::values(coarse) <- rnorm(terra::ncell(coarse))
      standardize(terra::resample(coarse, cells, method = "cubicspline"))
}
z <- standardize(Reduce(`+`, Map(function(s, w) w * noise(s), noise_scales, noise_weights)))
background <- bg_resistance * exp(bg_contrast * z)

letter_resistance <- letter_factor *
      terra::global(background, quantile, probs = letter_quantile)[[1]]
# blend in log space, so a half-covered cell gets the geometric mean of the two resistances
resistance <- exp(letters * log(letter_resistance) + (1 - letters) * log(background))
names(resistance) <- "resistance"

# connectivity --------------------------------------------------------------------------------

# exact current between the centers of the landscape's top and bottom edges
locations <- cbind(0, c(-half_h, half_h))

# flow <- cs_pairwise(resistance, locations, four_neighbors = TRUE)$current_map
flow <- cs_pairwise(resistance, locations, avg_resistances = TRUE)$current_map
# flow <- dp_pairwise(resistance, locations, method = "exact")$current

flow <- as.data.frame(flow, xy = TRUE)
names(flow) <- c("X", "Y", "current")

in_hex <- function(X, Y, r) abs(X) <= sqrt(3) / 2 * r & abs(Y) <= r - abs(X) / sqrt(3)
v <- sqrt(flow$current)
lim <- quantile(v[in_hex(flow$X, flow$Y, R)], stretch)
v <- pmin(pmax((v - lim[1]) / diff(lim), 0), 1)
flow$fill <- col$current[1 + round(255 * v)]

# plot ----------------------------------------------------------------------------------------

p <- ggplot() +
      geom_raster(data = flow, aes(X, Y, fill = rank(current)^2)) +
      coord_equal(xlim = c(-1, 1) * sqrt(3) / 2 * R, ylim = c(-1, 1) * R, expand = FALSE) +
      theme_void() +
      theme(legend.position = "none", plot.margin = margin(0, 0, 0, 0),
            plot.background = element_blank(), panel.background = element_blank()) +
      scale_fill_gradientn(colors = viridisLite::magma(11),
                           values = c(0, .05, .1, .15, .3, .5, .7, .8, .87, .93, 1))

# render, mask to the hexagon, and add a border -----------------------------------------------

width <- sqrt(3) * inch_per_R             # hexagon width sqrt(3) R, height 2 R
height <- 2 * inch_per_R
hex_angles <- (90 + 60 * 0:5) * pi / 180  # pointy-top

# The border is a filled ring of uniform width between two hexagons, drawn entirely inside the
# image, so its width is the same on every side and nothing is clipped at the edges. The outer
# hexagon is inset slightly so its points aren't cut off by the image boundary.
border_in <- 0.05                         # border width, inches (perpendicular to each side)
r_out <- inch_per_R * (1 - 0.004)         # outer hexagon circumradius, inches
r_in <- r_out - border_in / (sqrt(3) / 2) # inner: apothem smaller by exactly border_in
hex_npc <- function(r) list(x = 0.5 + r * cos(hex_angles) / width,
                            y = 0.5 + r * sin(hex_angles) / height)
outer <- hex_npc(r_out)
inner <- hex_npc(r_in)

render <- function(draw){
      f <- tempfile(fileext = ".png")
      ragg::agg_png(f, width = width, height = height, units = "in", res = dpi,
                    background = "transparent")
      grid::grid.newpage()
      draw()
      invisible(dev.off())
      magick::image_read(f)
}
art <- render(function() grid::grid.draw(ggplotGrob(p)))
mask <- render(function() grid::grid.polygon(outer$x, outer$y,
                                             gp = grid::gpar(col = NA, fill = "black")))
border <- render(function() grid::grid.path(c(outer$x, inner$x), c(outer$y, inner$y),
                                            id = rep(1:2, each = 6), rule = "evenodd",
                                            gp = grid::gpar(col = NA, fill = col$border)))
logo <- magick::image_composite(art, mask, operator = "DstIn")
logo <- magick::image_composite(logo, border, operator = "Over")
magick::image_write(logo, out_file)

# use_logo() resizes to fit `geometry` (default 240x278); twice that keeps fine detail sharp on
# high-DPI screens, since pkgdown and the README display the logo much smaller than this
usethis::use_logo(out_file, geometry = "480x556")
