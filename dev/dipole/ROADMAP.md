# Dipole methods: roadmap

The working task list for the `dp_*()` functions. Last reviewed 2026-11-24.

The v1 scope in `SPEC.md` §2 is built and merged. `dp_omni()`, `dp_pairwise()` and `dp_flux()` are as specified. The spec's gross pathways became `dp_omni(destination = )` and `dp_directionality()`. On top of the spec, `dp_circuit()`, power layers and progressr progress have also landed. Every test oracle in `SPEC.md` §5 has a test, and the benchmarks are in the dipole article. The §7 questions are settled in the code:

- the Julia code lives in `inst/julia/dipole.jl`;
- the endpoint injection term is left out, and that is documented;
- radius units are pixels or km;
- `dp_circuit()` and the `"halves"` attribute settle the API questions.

Items move here from `background.md`'s old "Next steps" and from design discussions. Check an item off when it lands, with the PR number, and add new ones in the section they fit. Decisions the spec marks as Matt's are flagged **(Matt)**.

## 1. Housekeeping

- [ ] **Report sampler setup as a progress step.** `random_dipoles()` builds the sampler before the first tick, about 1 s on a 600 × 600 grid and longer with a large radius, so the bar sits still. Add a "Preparing dipole sampler" step and count it in `dp_draw_steps()`.
- [ ] **Skip progress bookkeeping when `progress = FALSE`.** `dp_circuit_input()` still counts cells and `dp_draw_steps()` still calls Julia. Both are cheap but needless.
- [ ] **Run a full `R CMD check --as-cran`** before the next CRAN release. It hasn't been run since the power layers and progressr, which is a new Import.

## 2. Small additions

- [x] **Per-cell connectivity to targets: `dp_accessibility()` (#18; was `dp_isolation()`).** For every cell, the effective resistance to its targets: the other habitat within the radius for omni-type runs, or the destination for flux runs.
  - **Estimator:** random-sign dipoles across every link, scaled by √g, with one solve per draw on the factored circuit, so that E[(y_i − y_j)²] = R_ij. Per-cell statistics come from window sums of y and y², accumulated draw by draw. A 14 × 14 dense check found it unbiased, with median error 8% / 3% / 1% at 32 / 128 / 2000 draws for the mean-resistance statistic.
  - **Candidate statistics:**
    - mean effective resistance to targets;
    - resistance to the target distribution (one unit out, withdrawn across the reachable targets in proportion to their weight);
    - not the harmonic mean, because inverting a noisy estimate biases it.
  - **Decided (2026-11-24):**
    - a new `dp_isolation()` with a `dp_omni()`-like signature, scoring every cell;
    - both statistics, reported as resistance;
    - normalized layers and optional per-cell SEs;
    - `origin_`/`destination_` layers when there's a `destination`.
  - **Contact resistance:** single-cell resistance turned out to be dominated by the cell's own links (ρ 0.93 with local resistance on the example). Each cell therefore stands for a site of radius `site_radius` (default 2 px). `site_radius = 0` gives the single-cell reading, and `contact = TRUE` adds the exact contact layer. Subtracting contact was considered and is left to users; dividing by it flips the bias.
  - **Follow-up:** an exact per-site mode (one solve per site), deferred.
  - **Targets beyond the site (2026-11-24):** a cell's targets exclude its own site (the site version of j ≠ i), so tiny islands are NA rather than resistance ≈ 0. `radius` must reach beyond `site_radius`.
  - **Accessibility (2026-11-24):** `resistance` ignores how much target is in reach, since q is a share. `accessibility = TRUE` adds `target_area` (Σ t a over targets, km² from the CRS, else cells; exact) and `accessible_area` (target_area × R*/R, bias-corrected for inverting R), with R* the resistance in continuous habitat, solved exactly per kernel (per row on lon/lat), times `reference_resistance` (default 1). These replaced `coverage`/`effective_coverage` (#19), which were shares of the reach and so fell with radius. Accessible area still falls with radius at some cells (8% of core cells from 20 to 40 km on the synthetic landscape), from the fixed-proportion withdrawal; an amount-aware model without that, the settlement model, is sketched in `dev/settlement/DESIGN.md`. A mean-resistance analogue was skipped.
  - **Renamed to `dp_accessibility()` (2026-11-24):** `accessible_area` is the headline layer, and the area layers are always on (the `accessibility` flag is gone). Resistance became `conductance` (1/R, bias-corrected like accessible area; high = connected), with `normalized_conductance` = R_uniform/R. `mean_resistance` was dropped: its inverse isn't a mean of anything, and its main use was the link to `dp_omni()`'s total power. Cells with no targets beyond their site score 0 (normalized: NA) instead of NA; `contact` is now a conductance. `radius = Inf` omits `accessible_area` (no finite reference).
  - **`site_radius` stays a pixel default (2026-11-24):** 2 pixels, now always in pixels whatever `radius_units` (it used to follow them). It corrects a grid artifact (contact resistance), so it is a grid scale, not the dispersal scale. Making it required was tried and reverted: few users can choose it. The cost is resolution dependence (median accessible area +6–10%, core +29–42%, 2 km vs 0.5 km); the docs say to scale it to keep the same ground distance when comparing resolutions.
- [ ] **Resistance matrix from `dp_pairwise(method = "exact")`.** It needs no extra solves: solve v is a unit flow from focal node v to its component's first node, x_v (zero for that reference node), and R_ij = x_i(i) − x_i(j) − x_j(i) + x_j(j). So the matrix is the solves read at the focal nodes; pairs in different components get `Inf`/`NA`. With single-cell nodes it's the same quantity as `cs_pairwise()`'s `resistance_matrix`, contact resistance included, which is right for comparability with Circuitscape and IBR studies.
  - Offer it for the exact method only. Link dipoles could estimate it for the random method, but each entry would have about √(2/n_draws) noise, too much for a distance matrix.
  - API: lean towards a `"resistance_matrix"` attribute (keeps the SpatRaster return type, like `"n_pairs"`), with node IDs as dimnames.
- [ ] **Frame `dp_accessibility()` against one-to-all in its docs.** One-to-all grounds the other nodes, so current flows to the easiest targets, and its resistance is the minimum over all ways of splitting the withdrawal (Thomson), hence ≤ `dp_accessibility()`'s resistance, which withdraws in fixed proportions. One-to-all also outputs current maps, not per-node resistances, for a few focal nodes against all others equally. Add one-to-all to `dp_accessibility()`'s "closest established method" entry in the article.
- [ ] **`site_radius` for the random-dipole maps** (`dp_omni()`, and possibly `dp_pairwise()` and `dp_directionality()`).
  - **The problem:** the `power` layer has the same contact issue as single-cell isolation. A source cell's power includes its own pairs' dissipation on its own links, which scales with strength × resistance. A dense exact check on the example landscape (radius 15) split power into contact and pass-through parts:

    | Sources | Contact share of total power | Top-5% overlap with pass-through power |
    |---|---|---|
    | Default (conductance) | 8% | 0.98 |
    | Uniform | 38% | 0.64 |
    | Smooth habitat unrelated to resistance | 38% | 0.79 |

    Squared current is affected too, in the other direction: endpoint convergence is a median 17–29% of squared current at source cells.
  - **The fix:** spread each dipole endpoint over a site (the adjoint of `dp_accessibility()`'s site averaging: one window pass per draw on the injections). It changes every layer, so the default would be 0 to keep current results.
  - **Done so far:** documented the caveat in `?dp_omni` ("Power") and the article.
- [ ] **Per-cell uncertainty layer.** The per-parity sums already exist, so a per-cell error map comes almost free (SPEC §4, "Uncertainty"). Today only the `"halves"` summary is returned. Decide the form: an SE of current, a relative SE, or a halves-difference layer.
- [ ] **(Matt) Make `normalized_power` unitless?** It currently has units of resistance, because power on the uniform circuit uses unit conductance. A reference resistance, such as the mean cell resistance, would make it unitless.
- [ ] **(Matt) Weight `dp_directionality()`'s ratio by power?** Today it compares squared current only.
- [ ] **Interrupting long runs.** The progress callback runs in R once per batch, so it may be a place to honour Ctrl-C between batches. Untested.

## 3. Validation before dropping "experimental" or publishing

- [ ] **Real resistance with sharp barriers.** All the evidence so far is on smoothed suitability surfaces. Test agreement with Omniscape, and timings, on a land-cover or human-modification surface at 270–300 m.
- [ ] **Dipoles per draw at fine grain.** `n_dipoles = 1e5` was tuned at 0.73 M cells; at 330 m each cell gets 25× fewer endpoints. Check with the halves diagnostic (or the per-cell error map above) before any fine-grain speed claim.
- [ ] **Decompose the gap with Omniscape exactly on a small grid:** pairs vs stars, squared vs absolute current, window-truncated vs whole circuit. This is for the docs and the paper.
- [ ] **Equal-core pairwise comparison.** Run pairwise Circuitscape with its pair-level threading.
- [ ] **Literature search** on stochastic estimators of current density and on omnidirectional connectivity methods, before claiming novelty.

## 4. Deferred features (SPEC §2, "Deferred")

- [ ] **Tiling** for grids too big to factor whole (about 1e8 cells, or the 2.15-billion-nonzero cap). It uses 2R buffers, and the prototype is `prototype/dipole_tiling.R`. It works only for local kernels; the no-limit kernel can't be tiled. This is the largest engineering item.
- [ ] **Conditional pair weights**, the dipole counterpart of `os_condition()`: continuous climate-similarity weights, including matching present to future climate. Two-distribution pairing already exists through `destination`.
- [ ] **Absolute current via Cauchy weights.** The hook exists (`weight =` in `run_dipoles()`), but it needs about 10× the draws.
- [ ] **Pairing lost, stable and gained zones** for cross-era runs.
- [ ] **A fixed-proportion one-to-all cumulative current map.** True one-to-all (grounding the other nodes) needs a different circuit per node, so it doesn't fit the engine. But injecting e_i − q_i per node (withdrawn across the targets in proportion) does: random signs over those injections estimate Σ_i ‖I(e_i − q_i)‖² from a few dozen solves. Build only if users want the one-to-all current map.
- [ ] **Restoration gradient maps and optimization.**
- [ ] **Random-sign monopoles with distributed loss** (mortality and settlement). Dipoles don't combine with grounds; see SPEC §6. Now being explored as a settlement-model family, with per-cell settlement probability as the amount-aware connectivity measure: see `dev/settlement/DESIGN.md` (draft, undecided).

## Outside this package (TreeShift)

These are kept for reference from `background.md`; they are tracked in the TreeShift repo, not here.

- Within-era connectivity layer on Update, with the uniform-circuit factorization cached per box and grain.
- Make the cross-era "no loss" setting lossless (a 1e-12 floor, or one scaled to cell count).
- Decide which cross-era measures TreeShift offers beside advanced mode: net flux, gross pathways, or both.

## Done (from `background.md`'s old "Next steps")

- [x] Implement in circuitscaper, natively in Julia with 64-bit indices and parallel draws: the `dp_*()` functions. Tiling is still open, above.
- [x] Turn the small-grid exact check into a package unit test (`test-dipole-engine.R`, oracle 1).
- [x] Time fast exact pairwise on the 10-core machine at N = 25–1000.
- [x] Use the 1e-12 ground floor; the package does. Rerunning the prototype-era maps in `background.md` with it matters only for that document's figures.
