# Progress reporting of the dp_*() functions through 'progressr'

# Runs `expr`, recording the 'progressr' conditions it signals. Returns the
# value, the number of steps the progressor was created with, the amounts
# of its updates, their messages, and the condition types.
capture_progress <- function(expr) {
  withr::local_options(progressr.enable = TRUE)
  ev <- list()
  value <- withCallingHandlers(expr, progression = function(c) {
    ev[[length(ev) + 1]] <<- c
  })
  type <- vapply(ev, function(c) c$type, "")
  upd <- ev[type == "update"]
  list(value = value, type = type,
       steps = if (length(ev)) ev[[1]]$steps else NA,
       amount = vapply(upd, function(c) c$amount, 0),
       message = unlist(lapply(upd, function(c) c$message)))
}

# Each step is announced (amount 0, with a message) and then completed
# (amount 1), and the amounts add up to the number of steps
expect_steps <- function(p, steps) {
  expect_equal(p$type[1], "initiate")
  expect_equal(p$type[length(p$type)], "finish")
  expect_equal(p$steps, steps)
  expect_equal(sum(p$amount), steps)
  expect_equal(sum(p$amount == 0), steps)
  expect_true(all(nzchar(p$message)))
}

values_and_attributes <- function(r) {
  list(values = terra::values(r), names = names(r),
       halves = attr(r, "halves"), seed = attr(r, "seed"))
}

test_that("dp_omni reports a step per factorization, sampling and solve", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  # A small grid's batch is 32 draws, so 40 draws are 2 batches of 3 steps
  # (sampling, current, flow potential), after 2 factorizations
  p <- capture_progress(dp_omni(x$conductance, 5, x$suitability,
                                resistance_is = "conductances", n_draws = 40, seed = 1))
  expect_steps(p, 8)
  expect_equal(p$message[1:2], c("Factoring the circuit",
                                 "Factoring the uniform circuit (for flow potential)"))
  expect_equal(p$message[3:5], c("Sampling dipoles: draws 1-32 of 40",
                                 "Solving current: draws 1-32 of 40",
                                 "Solving flow potential: draws 1-32 of 40"))
  expect_equal(p$message[6], "Sampling dipoles: draws 33-40 of 40")

  # One circuit, plus the mean flow's solve with a destination
  p <- capture_progress(dp_omni(x$conductance, 5, x$suitability, destination = x$conductance,
                                resistance_is = "conductances", normalize = FALSE,
                                n_draws = 10, seed = 1))
  expect_steps(p, 4)
  expect_true("Solving the mean flow" %in% p$message)
})

test_that("a reused circuit's runs report only the factorizations they do", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  p <- capture_progress(dp_circuit(x$conductance, resistance_is = "conductances",
                                   flow_potential = FALSE))
  expect_steps(p, 1)
  circuit <- p$value
  # The uniform circuit is factored on first need, then reused
  p <- capture_progress(dp_omni(circuit, 5, x$suitability, seed = 1))
  expect_steps(p, 4)
  expect_equal(p$message[1], "Factoring the uniform circuit (for flow potential)")
  p <- capture_progress(dp_omni(circuit, 5, x$suitability, seed = 1))
  expect_steps(p, 3)
})

test_that("dp_directionality, dp_flux and dp_pairwise report progress", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  p <- capture_progress(dp_directionality(x$conductance, x$suitability, x$conductance,
                                          radius = 5, resistance_is = "conductances",
                                          seed = 1))
  # 2 factorizations, 2 mean-flow solves, 1 batch of 3
  expect_steps(p, 7)
  p <- capture_progress(dp_flux(x$conductance, x$suitability, x$conductance,
                                resistance_is = "conductances", normalize = FALSE))
  expect_steps(p, 2)

  tmpl <- x$conductance
  loc <- cbind(terra::xFromCol(tmpl, c(3, 15, 28)), terra::yFromRow(tmpl, c(3, 20, 5)))
  p <- capture_progress(dp_pairwise(tmpl, loc, resistance_is = "conductances",
                                    n_draws = 70, seed = 1))
  # 3 batches (32, 32, 6 draws) of 3 steps
  expect_steps(p, 2 + 9)
  # The exact method: one step per circuit, in fractions per batch
  p <- capture_progress(dp_pairwise(tmpl, loc, method = "exact",
                                    resistance_is = "conductances"))
  expect_steps(p, 4)
})

test_that("dp_accessibility reports a step per factorization, solve and summing", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  # 40 draws: 2 batches of 3 steps (current and uniform solves, summing),
  # then one for the continuous-habitat references
  p <- capture_progress(dp_accessibility(x$conductance, 5, 2, x$suitability,
                                         resistance_is = "conductances", n_draws = 40,
                                         seed = 1))
  expect_steps(p, 2 + 6 + 1)
  expect_equal(p$message[3:5], c("Solving link dipoles: draws 1-32 of 40",
                                 "Solving link dipoles on the uniform circuit: draws 1-32 of 40",
                                 "Summing over targets: draws 1-32 of 40"))
  # With no distance limit there is no reference
  p <- capture_progress(dp_accessibility(x$conductance, Inf, 2, x$suitability,
                                         resistance_is = "conductances", n_draws = 40,
                                         seed = 1))
  expect_steps(p, 2 + 6)
})

test_that("progress doesn't change results", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid(split = TRUE)
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  runs <- list(
    function(progress) dp_omni(circuit, 5, x$suitability, n_draws = 40, seed = 3,
                               power = TRUE, progress = progress),
    function(progress) dp_omni(circuit, 5, x$suitability, destination = x$conductance,
                               seed = 3, progress = progress),
    function(progress) dp_directionality(circuit, x$suitability, x$conductance,
                                         radius = 5, seed = 3, progress = progress)
  )
  for (f in runs) {
    with <- capture_progress(f(TRUE))
    expect_gt(length(with$amount), 0)
    without <- capture_progress(f(FALSE))
    expect_length(without$type, 0)
    expect_identical(values_and_attributes(with$value),
                     values_and_attributes(without$value))
  }
})

test_that("nothing is shown without a progress handler", {
  skip_if_no_julia(circuitscape = FALSE)
  x <- dipole_test_grid()
  circuit <- dp_circuit(x$conductance, resistance_is = "conductances")
  withr::local_options(progressr.enable = TRUE)
  expect_silent(dp_omni(circuit, 5, x$suitability, seed = 1))
})
