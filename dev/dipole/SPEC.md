# Dipole methods: implementation spec

Status: ready to implement (2026-11-17). Written from a long design and prototyping effort in claude.ai. `background.md` (in this folder) has the full history, benchmarks and reasoning; this file is the contract. Where they differ, this file wins.

## 1. What we are building

A family of circuit-theory connectivity operations that share one engine: **a circuit factored once, then many balanced injections ("dipoles") solved against it, combined by superposition.** They are exposed in circuitscaper beside `cs_*()` and `os_*()` as `dp_*()` functions.

The flagship is the **random-dipole method**, an omnidirectional connectivity map that plays Omniscape's role. Instead of solving one circuit per target window, it estimates a kernel-weighted sum over all habitat cell pairs of each pair's squared current on the whole circuit. It takes one factorization and about 32 solves, whatever the number of pairs. In benchmarks it was 10–23× faster than Omniscape on equal cores, and 25–58× with factorizations reused.

Why squared current: for a unit flow between i and j, the squared current through a link equals the derivative of their effective resistance with respect to that link's resistance (Thomson's principle). So the map is the sensitivity of kernel-weighted total pairwise resistance among habitat to degrading each link. This interpretation, and the evidence against Omniscape-style absolute current with window truncation, are in `background.md` under "How the random-dipole method differs from Omniscape" and "Related work and novelty".

## 2. Scope

### Version 1 (build now)

1. **`dp_omni()`: random dipoles, Omniscape-like.** Habitat-weighted sources, disk kernel of a given radius or no distance limit. Outputs current, flow potential and normalized current.
2. **`dp_pairwise()`: random dipoles over focal nodes.** Every pair of N focal nodes in each draw, with independent standard-normal pair weights. Squared-current analogue of pairwise Circuitscape at a cost independent of N.
3. **`dp_flux()`: cross-era net flux.** Present habitat injects and future habitat withdraws fixed amounts, each summing to 1. One deterministic solve; signed flow, so direction is available.
4. **`dp_pathways()`: cross-era gross pathways.** Random-sign dipoles with one end drawn from present habitat and the other from future habitat, within a radius or unlimited. Magnitude only.

Function names are provisional; keep them consistent with the package's existing style.

### Deferred (design for, don't build)

- **Absolute current via Cauchy weights.** Stable-distribution estimator; about 10× the draws. Leave a hook for the dipole-weight distribution.
- **Lost/stable/gained zone pairing** for cross-era runs.
- **Tiling** for grids too big to factor whole; 2R buffers, prototype in `prototype/dipole_tiling.R`.
- **Continuous climate-similarity pair weights.**
- **Restoration gradient maps and optimization.**
- **Random-sign monopoles with distributed loss** (mortality and settlement).

See `background.md` and the claude.ai project doc `dev-ideas.md`.

### Excluded

- **Fast exact pairwise** (Brandes & Fleischer sort trick). It is being proposed upstream to Circuitscape.jl as a pairwise cumulative-map shortcut; do not implement it here.
- **Anything that mimics Omniscape's window truncation** (leak or tiles as truncation). Tested; rejected.

## 3. Definitions

### Graph

- **Nodes:** the non-NA cells of the conductance raster.
- **Links:** 8-neighbour. Orthogonal links have conductance (c_u + c_v)/2; diagonal links have (c_u + c_v)/(2√2). This matches Circuitscape's raster graph with averaged conductances.
- **Matrix:** Laplacian L plus a diagonal floor of **1e-12** per node, which keeps it positive definite. Balanced injections carry no net current, so the floor's only job is to make Cholesky work. At 1e-8 it measurably drained current from low-conductance cells; 1e-12 and 1e-15 both matched Circuitscape. An alternative is Dirichlet-grounding one node per connected component, which is exact for balanced injections.
- **Connected components:** each component is a separate circuit. Dipoles with endpoints in different components must be rejected or handled per component. The prototype ignored this because its test surface was one component.

### Target quantity (`dp_omni`, `dp_pathways`)

For each link e:

    T_e = Σ_{i≠j} w_i w_j k(d_ij) I_e(i,j)²        (ordered pairs)

- w is source strength: habitat suitability, set to 0 below a threshold. Default threshold 0.01, as in the benchmarks.
- k is the kernel: 1 if the pair's distance is ≤ R, else 0. With no limit, k = 1 everywhere.
- I_e(i,j) is the current through e for a unit flow from i to j.

The cell value is **current = sqrt(½ Σ_{e ∋ cell} T_e)**, the RMS-style aggregation.

For `dp_pathways`, i runs over present-habitat weights and j over future-habitat weights. The question is symmetric in magnitude, so random signs are valid even though the pairing is one-way.

### Estimator

- **Sampling.** Draw M dipoles per draw. Each is an ordered pair (i, j) with probability q_ij = w_i w_j k_ij / S, where S = Σ_{i≠j} w_i w_j k_ij, and each gets a random sign s ∈ {−1, +1}.
- **Injection.** For each draw, b = Σ s (e_i − e_j). Solve L v = b.
- **Link current.** I_e(b) = g_e (v_a − v_b) for link e between nodes a and b.
- **Unbiasedness.** Cross terms vanish in expectation, so E[I_e(b)²] = (M/S) T_e, and the estimate is T̂_e = (S/M) · mean over draws of I_e(b)².

**Scale.** The prototype omitted the S/M factor, so its values depended on M. The package should apply it, so values are invariant to `n_dipoles` and comparable across runs. S is a focal sum of w over the kernel, multiplied by w and summed over cells, which is cheap to compute. The normalized layer is unaffected either way.

**Noise.** Each draw contributes a χ²₁-like factor, with relative SD ≈ 1.4 per draw, so noise falls as 1/√draws. More dipoles per draw only improve coverage of the pair distribution, and that benefit plateaus around 1e5–3e5. Defaults: **n_draws = 32, n_dipoles = 1e5.** At 2 km, 32 draws give about 6–12% per-cell noise in current and 3–10% in normalized.

### Kernel sampling

- **Prototype.** Sample i ∝ w, draw a uniform point in a continuous disk of radius R (in km, assuming lon/lat) around i, round to a cell, and accept with probability w_j / max(w). It rejects j = i and out-of-grid or NA cells.
- **Package.** Implement the kernel as the exact set of cell offsets within distance R, precomputed in map units and handling projected and geographic CRS. Draw a uniform offset, then accept with w_j / max(w). This makes the kernel exactly "cells within R", matching the reference outputs, which use a pixel circle (dr² + dc² ≤ R²).
- **No limit.** Sample i and j independently ∝ w and reject i = j.

### Flow potential and normalization

Use the same injections (same B) on a uniform circuit: conductance 1 on the same valid cells, same graph and floor. Flow potential is the same RMS cell value. **Normalized = current / flow potential.**

Note that this deliberately differs from Omniscape, which computes flow potential on a uniform square box per target. That box-shape mismatch with its circular current window produces an artifact.

### `dp_pairwise`

- **Weights.** Each draw injects b = Σ_{i<j} ξ_ij (e_i − e_j) with ξ_ij ~ N(0,1) independent. Build it as node sums, b_i = Σ_j ξ_ij − Σ_j ξ_ji (upper triangle), which costs O(N²) per draw.
- **Estimate.** Mean of I_e(b)² over draws estimates Σ_{i<j} I_e(i,j)² exactly in expectation.
- **Exact alternative.** From N solves (unit flow from node i to node 1), each link's sum over pairs is Σ_{i<j} (y_i − y_j)² = N Σ y_i² − (Σ y_i)². This is the test oracle, and it is worth exposing for N up to a few thousand.
- **Node values.** Each pair contributes half its unit injection at both endpoints. For squared current there is no established convention; see the open questions.

### `dp_flux`

- **Injection.** b = w_present / Σ w_present − w_future / Σ w_future. One solve.
- **Outputs.** Per-link signed currents. The cell layer is ½ Σ |I_e| over incident links. Optional layers: the x and y components of net flow per cell (direction), and squared-current magnitude.
- **No dispersal limit.** Pairing drops out, because only the cell totals matter.

## 4. Architecture

- **Julia core** in a module under `inst/julia/` (e.g. `dipole.jl`), loaded through the existing JuliaConnectoR backend. **R** handles inputs, validation, CRS and units, and returns SpatRasters. Follow the patterns in `R/julia-backend.R` and how `os_run()` is wired.
- **No dependency on Circuitscape.jl internals in v1.** Circuitscape 6 exports nothing, and its internals are moving fast. Use Julia's SparseArrays and CHOLMOD directly, mirroring Circuitscape's graph conventions exactly. Structure the code as graph construction, factorization, injections, then accumulation, with a solver abstraction, so it could later move upstream into Circuitscape.jl or Omniscape.jl (a long-term aim).
- **Performance:**
  - Factor once per circuit, and allow reusing factorizations across calls: same circuit with different radii, sources or kernels. The R API could take a prepared-circuit object.
  - Solve draws in batches of right-hand sides.
  - Accumulate squared link currents without materializing all draws: per-link running sums, split by draw parity for the uncertainty diagnostic.
  - Thread across draws or batches. In the R prototype, parallel draws helped only modestly, because most of a map's time went to building the graphs and factoring them.
  - Use 64-bit indices. At 330 m the factor reached 1.7 billion nonzeros, near the 32-bit limit.
- **Data exchange.** Pass rasters to Julia either as arrays through JuliaConnectoR or via temp files, as the package does now. Choose on measured speed for about 10⁷ cells.
- **Reproducibility.** Accept a `seed`. Results must be reproducible given the seed and thread count, or document if not.
- **Uncertainty.** Keep per-parity sums so a half-vs-half agreement diagnostic, and later a per-cell error map, comes for free.

## 5. Validation (the test oracles)

1. **Exact small-grid check.** `prototype/dipole_check.R` computes T_e exactly by dense pseudo-inverse on a small grid. The estimator's mean over many draws must converge to it as 1/√draws with no bias. As a package test: fixed seed, enough draws, tolerance from the theoretical SD.
2. **Deterministic parity with the prototype.** Expose an internal hook that takes a user-supplied dipole list or injection matrix B. Given the same B, the Julia accumulation must match `prototype/dipole.R`'s `dp_accumulate()` to numerical precision. This separates engine bugs from RNG differences.
3. **Reference crop.** `reference/crop_R6_reference.tif` is a 64 × 64 crop of the 2 km *Pinus edulis* surface. Layers:
   - `suitability`, `conductance`, `source_strength` (inputs);
   - `exact_current`, `exact_flow_potential`: exact target cell values for R = 6 px, pixel-circle kernel, ordered pairs, product weights, whole crop as the circuit, cell = sqrt(½ Σ incident T_e);
   - `omniscape_current`, `omniscape_flow_potential`: exact Omniscape at block size 1, validated against a real `os_run` at ρ ≥ 0.9999.

   With the S/M scaling, `dp_omni()` at R = 6 px must have mean squared cell values converging to `exact_*`² (unbiased). Against the Omniscape layers, expect normalized Spearman ρ ≈ 0.85 and current ρ ≈ 0.99. That is not a bug; see `background.md` "Exact decomposition".
4. **`dp_pairwise` vs the exact N-solve version.** Agreement ρ ≈ 0.999 at 32 draws across N = 25–1000.
5. **`dp_flux`.** One solve; must match `prototype/pairscape_crossera.R`'s net flux to numerical precision on the same inputs.
6. **Benchmarks to reproduce, roughly**, on the 2 km surface (728k cells, 10-core Mac, Accelerate BLAS):
   - about 5 s per `dp_omni` map, including two factorizations;
   - `dp_pairwise` about 3 s at any N.

   Julia should beat the R prototype. Scripts are in `prototype/` (TreeShift paths).

## 6. Known pitfalls

- **Node order.** The prototype numbers nodes column-major over the wide matrix, while terra cell order is row-major. A mismatch gave a Spearman of 0.29 once. Test orientation explicitly.
- **Ground floor.** See §3. Never let a floor or leak drain measurable current.
- **Distributed grounds or loss do not combine with dipoles.** Fixed withdrawals plus ground leakage pull current up from ground near sinks. Loss belongs to a future monopole mode; see `background.md` and `dev-ideas.md`.
- **Edges.** Squared current on the whole circuit is as edge-robust as Omniscape. No special edge handling is needed.
- **Memory.** Don't hold all draws' voltages for big grids. Batch, and accumulate per link.
- **Components and NA.** Handle multiple connected components, NA holes and cells with w = 0.

## 7. Open questions (decide during implementation; ask Matt if unclear)

- **Julia code location.** `inst/julia/dipole.jl` inside circuitscaper (default), or a separate small Julia package that circuitscaper depends on.
- **Injection term at endpoints.** Whether to add an injection term to squared-current cell values, analogous to Circuitscape's half-injection at endpoints. Absolute-current comparisons need it; for squared current it is a convention choice. Default: omit, and document.
- **Radius units.** Map units vs km; CRS handling.
- **API details.** The prepared-circuit object for factorization reuse; whether `dp_omni` returns the halves diagnostic; argument names aligned with `os_run()` (`radius`, `source_strength`, `resistance_is`, …).

## 8. Files in this folder

- `SPEC.md`: this file.
- `background.md`: the full design document exported from claude.ai: methods, validation, benchmarks, Omniscape comparison, cross-era work, related work.
- `prototype/`: the reference R prototype and validation scripts, copied from the TreeShift repo's `sandbox/`. Paths inside assume the TreeShift project root; see `prototype/README.md`.
- `reference/crop_R6_reference.tif`: the reference crop (§5.3).
