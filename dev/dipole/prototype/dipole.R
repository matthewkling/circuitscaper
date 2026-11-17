# Superposed random dipoles: within-era connectivity that estimates
# kernel-weighted pairwise squared current from one factorization and a block
# of solves. Sourced by sandbox/dipole_connectivity.R, which explains the method.

library(terra)

# Circuit on the non-NA cells of `conductance`, as Circuitscape's raster graph
# with 8 neighbours and averaged conductances (src/raster/graph.jl)
# The ground floor keeps the matrix positive definite; at 1e-8 it drained
# measurable current from low-conductance areas, so it is kept far smaller.
dp_graph <- function(conductance, ground_floor = 1e-12) {
      cm <- as.matrix(conductance, wide = TRUE)
      nr <- nrow(cm); nc <- ncol(cm)
      valid <- !is.na(cm)
      n <- sum(valid)
      id <- matrix(NA_integer_, nr, nc)
      id[valid] <- seq_len(n)

      links <- function(dr, dc) {
            rs <- seq_len(nr - dr)
            cs <- max(1, 1 - dc):min(nc, nc - dc)
            a <- id[rs, cs]; b <- id[rs + dr, cs + dc]
            ok <- !is.na(a) & !is.na(b)
            g <- (cm[rs, cs][ok] + cm[rs + dr, cs + dc][ok]) / 2
            if (dr != 0 && dc != 0) g <- g / sqrt(2)
            list(a = a[ok], b = b[ok], g = g)
      }
      edges <- list(links(0, 1), links(1, 0), links(1, 1), links(1, -1))

      ea <- unlist(lapply(edges, `[[`, "a"))
      eb <- unlist(lapply(edges, `[[`, "b"))
      eg <- unlist(lapply(edges, `[[`, "g"))
      A <- Matrix::sparseMatrix(i = c(ea, eb), j = c(eb, ea), x = c(eg, eg), dims = c(n, n))
      L <- Matrix::forceSymmetric(Matrix::Diagonal(x = Matrix::rowSums(A) + ground_floor) - A)
      fac <- Matrix::Cholesky(L, perm = TRUE, super = TRUE)

      list(fac = fac, edges = edges, n = n, nr = nr, nc = nc, valid = valid, id = id,
           node_r = row(cm)[valid], node_c = col(cm)[valid], template = conductance)
}

# Dipole endpoints, drawn in proportion to w_i * w_j * k(d_ij), k a uniform
# disk of `radius` km (Inf: no distance limit). Proposals are made in chunks
# to bound memory.
dp_sample <- function(g, w, m, radius, chunk = 4e6) {
      lat_mid <- mean(as.vector(ext(g$template))[3:4])
      px_x <- res(g$template)[1] * 111.32 * cos(lat_mid * pi / 180)
      px_y <- res(g$template)[2] * 110.57
      wmax <- max(w)
      out_i <- out_j <- integer(m)
      got <- 0
      while (got < m) {
            k <- as.integer(min(chunk, 4 * (m - got) + 1000))
            i <- sample.int(g$n, k, replace = TRUE, prob = w)
            if (is.finite(radius)) {
                  rr <- radius * sqrt(runif(k))
                  th <- runif(k, 0, 2 * pi)
                  r2 <- g$node_r[i] + round(rr * sin(th) / px_y)
                  c2 <- g$node_c[i] + round(rr * cos(th) / px_x)
                  inb <- r2 >= 1 & r2 <= g$nr & c2 >= 1 & c2 <= g$nc
                  j <- rep(NA_integer_, k)
                  j[inb] <- g$id[cbind(r2[inb], c2[inb])]
                  ok <- which(!is.na(j) & j != i)
                  ok <- ok[runif(length(ok)) < w[j[ok]] / wmax]
            } else {
                  j <- sample.int(g$n, k, replace = TRUE, prob = w)
                  ok <- which(j != i)
            }
            take <- head(ok, m - got)
            out_i[got + seq_along(take)] <- i[take]
            out_j[got + seq_along(take)] <- j[take]
            got <- got + length(take)
      }
      list(i = out_i, j = out_j)
}

# Injection matrix: one column per draw, `m` unit dipoles with random signs,
# summed per node
dp_injections <- function(g, w, n_draws, m, radius) {
      d <- dp_sample(g, w, n_draws * m, radius)
      s <- sample(c(-1, 1), n_draws * m, replace = TRUE)
      col <- rep(seq_len(n_draws), each = m)
      as.matrix(Matrix::sparseMatrix(i = c(d$i, d$j), j = c(col, col), x = c(s, -s),
                                     dims = c(g$n, n_draws)))
}

# Sum over draws of squared link current, per cell, split by draw parity.
# `B` columns are solved `batch` at a time.
dp_accumulate <- function(g, B, batch = 8) {
      acc <- matrix(0, g$n, 2)
      starts <- seq(1, ncol(B), by = batch)
      for (s0 in starts) {
            cols <- s0:min(ncol(B), s0 + batch - 1)
            V <- as.matrix(Matrix::solve(g$fac, B[, cols, drop = FALSE], system = "A"))
            par <- (cols %% 2) + 1   # 2 for odd draws, 1 for even
            for (e in g$edges) {
                  I2 <- (e$g * (V[e$a, , drop = FALSE] - V[e$b, , drop = FALSE]))^2
                  for (p in 1:2) {
                        k <- par == p
                        if (!any(k)) next
                        x <- rowSums(I2[, k, drop = FALSE])
                        acc[e$a, p] <- acc[e$a, p] + x
                        acc[e$b, p] <- acc[e$b, p] + x
                  }
            }
      }
      acc
}

# A raster's values in node order. Nodes are numbered down the columns of
# the wide matrix, not in terra's row-major cell order.
dp_node_values <- function(g, r) as.matrix(r, wide = TRUE)[g$valid]

dp_raster <- function(g, v, name) {
      m <- matrix(NA_real_, g$nr, g$nc)
      m[g$valid] <- v
      setNames(setValues(g$template, as.vector(t(m))), name)
}

# Agreement between the two half-estimates (even vs odd draws) of a map
dp_halves <- function(h1, h2, mask = rep(TRUE, length(h1))) {
      pos <- mask & h1 > 0 & h2 > 0
      c(spearman = cor(h1[pos], h2[pos], method = "spearman"),
        med_rel_diff = median(abs(h1[pos] - h2[pos]) / ((h1[pos] + h2[pos]) / 2)))
}

# Within-era connectivity for one kernel radius.
#
# suit: source strength w (e.g. occurrence probability); conductance: the
# circuit; radius_km: disk kernel radius (Inf: no distance limit).
# Returns layers `current` (RMS link current), `flow_potential` (the same
# dipoles on a uniform-conductance circuit; NULL unless normalize) and
# `normalized` (their ratio), with the halves diagnostics and timings as
# attributes. Graphs can be passed in to reuse their factorizations.
dp_connectivity <- function(suit, conductance, radius_km, n_draws = 32, n_dipoles = 1e5,
                            normalize = TRUE, g = NULL, g0 = NULL) {
      stopifnot(n_draws %% 2 == 0)
      tm <- c()
      t0 <- Sys.time()
      if (is.null(g)) g <- dp_graph(conductance)
      if (normalize && is.null(g0)) g0 <- dp_graph(mask(setValues(conductance, 1), conductance))
      tm["graphs"] <- difftime(Sys.time(), t0, units = "secs")

      w <- dp_node_values(g, suit)
      w[is.na(w) | w < 0] <- 0

      t0 <- Sys.time()
      B <- dp_injections(g, w, n_draws, n_dipoles, radius_km)
      tm["sampling"] <- difftime(Sys.time(), t0, units = "secs")

      t0 <- Sys.time()
      a <- dp_accumulate(g, B)
      a0 <- if (normalize) dp_accumulate(g0, B)
      tm["solves"] <- difftime(Sys.time(), t0, units = "secs")

      hab <- w > 0.01
      cur <- sqrt(rowSums(a) / n_draws / 2)
      out <- dp_raster(g, cur, "current")
      diag <- rbind(current = dp_halves(sqrt(a[, 1]), sqrt(a[, 2]), hab))
      if (normalize) {
            fp <- sqrt(rowSums(a0) / n_draws / 2)
            out <- c(out, dp_raster(g, fp, "flow_potential"), dp_raster(g, cur / fp, "normalized"))
            ok <- hab & a0[, 1] > 0 & a0[, 2] > 0
            diag <- rbind(diag, normalized = dp_halves(sqrt(a[, 1] / a0[, 1]), sqrt(a[, 2] / a0[, 2]), ok))
      }
      attr(out, "halves") <- diag
      attr(out, "seconds") <- round(tm, 1)
      out
}
