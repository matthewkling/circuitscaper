# Prototype scripts

These are copies of the R prototype from the TreeShift repo's `sandbox/`, taken 2026-11-17. They are the reference behaviour for the Julia implementation; don't edit them in place. Paths inside assume the TreeShift project root (`sandbox/...`, `sandbox/connectivity_bench/...`), whose inputs and outputs are not copied here.

| File | What it is |
|---|---|
| `dipole.R` | **The engine.** `dp_graph()` builds the graph and factorization; `dp_sample()` and `dp_injections()` sample dipoles; `dp_accumulate()` gives squared link currents per cell, split by draw parity; `dp_connectivity()` runs the Omniscape-like mode. The ground floor here is 1e-12. |
| `dipole_check.R` | Exact small-grid check: the dense pseudo-inverse target against the estimator, with convergence by draws. Oracle 1 in SPEC.md. |
| `dipole_connectivity.R` | Driver that maps *P. edulis* at r = 50 km and with no limit. |
| `dipole_tiling.R` | Tiled vs untiled runs; a 2R buffer gives 0.19% median error (deferred feature). |
| `pairscape_pairwise.R` | Focal-node mode (Gaussian pair weights), the exact N-solve squared version, and comparison with `cs_pairwise()`. |
| `pairscape_crossera.R` | Cross-era net flux and gross pathways vs TreeShift's advanced-mode model, plus the leakage check. |
| `dipole_factorial.R` + `dipole_factorial/` | Exact factorial decomposition against an exact R reimplementation of Omniscape (pairs/stars × squared/absolute × whole/window × weights × flow-potential shape), toy-landscape tests (barrier, weak spot, corridor, edges), and validation against real `os_run`. `pairs.cpp` is an Rcpp exact pair-sum kernel. This is the source of the reference crop. |

The scripts and results still call the random-dipole method "Pairscape", its earlier name.
