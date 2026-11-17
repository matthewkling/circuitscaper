> Exported from the Claude Doc "Dipole methods" (rev 42, 2026-11-17). Background and history of decisions; the implementation spec is SPEC.md, which takes precedence where they differ. Script paths refer to the TreeShift repo's sandbox/; copies of the key prototype scripts are in prototype/.

# Dipole methods: fast pairwise, omnidirectional and cross-era circuit connectivity

Nov 15, 2026 · @Matthew Kling

## Summary

The random-dipole method maps kernel-weighted pairwise circuit connectivity from one factorization and about 32 random draws, whatever the number of node pairs. Each draw superposes many source–sink pairs with random signs in one circuit; averaging squared link currents over draws recovers the sum of every pair's squared current exactly in expectation.

**Name.** Most of these methods inject balanced dipoles, current in at one place and the same amount out at another, with no grounds: random-sign dipoles for omnidirectional and all-pairs maps, and one spread-out dipole for cross-era net flux. Fast exact pairwise is different: it is an ordinary source–ground calculation with the ground held at one reference node. It belongs to the family because it shares the engine, superposition on one factored circuit, not because it uses dipoles. Earlier drafts called the random-sign method Pairscape; script file names still say `pairscape_`.

**Framing.** The random-dipole method treats pairwise and omnidirectional circuit connectivity as two settings of one quantity, a kernel-weighted sum over cell pairs, and estimates it at a cost independent of the number of pairs. With no distance limit over focal nodes it targets the same pairs as pairwise Circuitscape (ρ 0.98–0.997); with a local kernel over habitat-weighted cells it plays Omniscape's role (current ρ 0.95–0.98, normalized ≈ 0.86), differing in using squared rather than absolute current and the whole circuit rather than truncated windows. Informally, it combines Circuitscape's whole-circuit pairs with Omniscape's habitat-weighted, distance-limited sources; it is not a combination of their algorithms, and its outputs match neither exactly.

Results so far, on a *Pinus edulis* suitability surface (TreeShift default box, 2 km, 0.73 M cells):

- **Exactness:** converges to the exact pairwise sum on a brute-force test grid, with no detectable bias and error falling as 1/√draws.
- **vs pairwise Circuitscape** (same focal nodes, one core each): 65× faster at 100 nodes, 240× at 200, an extrapolated \~5000× at 1000; maps agree at ρ = 0.98–0.997.
- **vs Omniscape** (10 cores each, 2 km): 10–23× faster, 25–58× with factorizations reused; current agrees at ρ = 0.95–0.98, normalized current at ρ ≈ 0.86.
- **At realistic scale** (330 m, 18 M cells, 50 km radius, estimated): 10–15× faster than 10-thread Omniscape with tiles in parallel, about 20× with factorizations reused.
- **A side result:** for N focal nodes, the exact all-pairs squared-current map needs only N solves, about 100× faster than pairwise Circuitscape at N = 200.

The random-dipole method computes a related but different quantity from Circuitscape and Omniscape (squared rather than absolute current, on the whole circuit rather than truncated windows), and its maps carry about 6–12% sampling noise per cell at 32 draws.

## Beyond speed

The dipole approach removes several arbitrary choices that shape current connectivity maps, and adds capabilities the existing tools lack. The strongest selling points are the first, third, fourth and fifth.

1. **No node placement.** Pairwise Circuitscape needs focal nodes, and its maps depend on that choice: the 200-node maps here changed with the sample. The dipole method can treat every habitat cell as a node, weighted by quality, removing core-area delineation and the sensitivity to it.
2. **Fewer arbitrary settings.** No block size, window truncation, wall placement or speed-driven source threshold. The one scale parameter is the kernel, an ecological quantity (dispersal distance) rather than a computational one. With a local kernel, results depend on the bounding box only within about one radius of its edges, unlike wall-to-wall.
3. **Real dispersal kernels.** Omniscape's window is a hard cutoff. Any kernel shape (negative exponential, fat-tailed, or fitted to dispersal data) is a one-line sampler change, so connectivity reflects how organisms move rather than an all-or-nothing radius.
4. **One framework for several analyses.** The choice of pair weights gives pairwise (no limit), omnidirectional (local kernel), focal-node or conditional connectivity, with the same method and code. A natural extension: pairs weighted by present-era strength at one end and future-era strength at the other, a pairwise form of climate-tracking connectivity.
5. **Built-in uncertainty.** Every map comes with an error estimate from the halves check, and users set the accuracy–time trade-off through the number of draws. Maps also refine progressively: a rough map after a few draws sharpens as more arrive, which suits interactive tools.
6. **Cheap sensitivity and multi-scale analysis.** Window size is often the choice that most changes Omniscape results. With factorizations reused, sweeping radii, kernels or source definitions costs a fraction of one Omniscape run, so exploring those choices becomes routine.
7. **Multispecies in one run.** The target is a sum over pairs, so several species sharing one resistance surface can be combined into one pair distribution, each with its own sources and kernel, for about the cost of a single map.
8. **Easy to run.** A laptop and plain R: no Julia, no HPC. That matters for agency staff and for web apps such as TreeShift.
9. **A precise definition.** The output is a clearly defined quantity, with an exact small-grid check and, for focal nodes, an exact N-solve version. Omniscape's output partly depends on implementation choices (blocking, window clipping).

Points 1, 2, 5, 8 and 9 rest on results in this doc. Points 3 and 6 follow directly from the method but have no worked example yet; the cross-era pairs in 4 and the multispecies run in 7 are untested and need a demonstration before they go in a paper as more than proposals.

## Motivation

TreeShift partners asked for within-era connectivity (how connected a species' habitat is today, or in a future era) alongside the app's existing cross-era range-shift connectivity. The standard tools for that are too slow for an interactive app:

- **Pairwise Circuitscape** solves one circuit per node pair and adds up |current| over pairs, so cost grows with N². At 0.73 M cells it took \~39 ms per pair: 13 minutes for 200 nodes, with 200 nodes still a sparse sample of the habitat.
- **Omniscape** solves one window circuit per target block; 48–116 s per map on 10 threads at 2 km, and hours on the 90–300 m grids typical of published analyses.
- **Wall-to-wall** is fast (two full-grid solves) but its map depends on the bounding box and flow directions, which is a poor fit for an app where users move the box.

The naive fast alternative fails: sources and grounds both proportional to the same habitat surface give exactly zero flow, because a uniform voltage then satisfies the circuit. The dipole method gets around that by superposing explicit source–sink pairs with random signs.

## Method

The random-dipole method estimates, for every link e of the circuit, a kernel-weighted sum over cell pairs of the squared current that pair drives through e:

```latex
T_e = \sum_{i<j} p_{ij}\, I_e(i,j)^2, \qquad p_{ij} = w_i\, w_j\, k(d_{ij})
```

Here I\_e(i, j) is the current on e when one unit enters at cell i and leaves at cell j, w is source strength (e.g. habitat suitability), and k is a distance kernel: a disk of radius R for an Omniscape-like analysis, or k = 1 for all pairs, as in pairwise Circuitscape.

**Circuit.** The 8-neighbour raster graph Circuitscape builds by default: link conductance (cᵤ + cᵥ)/2, diagonals divided by √2. A uniform ground floor of 1e-8 per cell keeps the matrix positive definite; injections are balanced, so it carries almost no current.

**Estimator.** Each draw builds one injection from M dipoles (+1 at i, −1 at j), pairs drawn in proportion to pᵢⱼ, each with a random sign s:

```latex
b = \sum_{d=1}^{M} s_d \,(e_{i_d} - e_{j_d}), \qquad \mathbb{E}\big[I_e(b)^2\big] = \tfrac{2M}{S}\, T_e
```

with S the sum of p over ordered pairs. Superposition makes the solved current the exact sum of each dipole's current; squaring adds cross terms between dipoles, and random signs make each cross term average to zero. Pairs are sampled by rejection: i in proportion to w, a partner offset uniformly within the disk, kept with probability wⱼ / max(w).

**Draws and dipoles.** One draw is noisy: once dipoles are dense enough, its squared current is the target times a χ²₁ factor (relative SD ≈ 1.4), whatever the number of dipoles. Averaging k draws cuts that as 1/√k. More dipoles per draw only improve coverage of the pair population, which saturates around 1e5–3e5 at 0.73 M cells. Default: 32 draws × 1e5 dipoles.

**Cost.** The circuit is the same in every draw, so it is factored once (CHOLMOD, via `Matrix::Cholesky`) and all draws are solved against the factor. A map costs one factorization plus about 32 cheap solves, independent of the number of pairs and nearly independent of R.

**Output.** Per cell, the RMS link current: √(sum over the cell's links of the mean squared current / 2).

**Normalization.** The same dipoles on a uniform-conductance circuit give a flow potential; current ÷ flow potential separates channelled (> 1) from impeded (< 1) flow, as in Omniscape. Reusing the dipoles cancels most sampling noise in the ratio.

**Focal nodes.** For a fixed set of N nodes, two variants:

- *Random dipoles over nodes:* each draw weights every one of the N(N−1)/2 pairs by an independent standard normal, in one solve; no pair sampling at all.
- *Exact squared current:* with yᵢ the current on a link when node i is the source, the all-pairs sum needs only N solves, since

```latex
\sum_{i<j} (y_i - y_j)^2 = N \sum_i y_i^2 - \Big(\sum_i y_i\Big)^2
```

**Related work.** Random-sign probes and a few Laplacian solves in place of many exact ones are established for effective resistance and current-flow centrality ([Bergamini et al. 2016](https://arxiv.org/pdf/1607.02955), building on Spielman and Srivastava's random-projection estimator). The estimator here is a Hutchinson-type diagonal estimator in that family; what appears new (from a quick search, not a literature review) is its use for kernel-weighted current-density maps in landscape connectivity.

## Validation

The estimator converges to the exact pairwise sum with no detectable bias, and its noise falls as 1/√draws.

**Exact check.** On a 40 × 40 grid (1,584 cells) with patchy conductance spanning four orders of magnitude, a barrier with a gap, a block of NA cells and patchy suitability, the target was computed exactly from the dense inverse and compared per cell with the estimator (2,000 dipoles per draw). The disk kernel's target used the kernel exactly as the sampler realizes it.

| Kernel | Draws | Median error per cell | 95th pct error | Normalized, median error |
| --- | --- | --- | --- | --- |
| No limit | 32 | 14.9% | 43% | 5.8% |
| No limit | 512 | 3.1% | 9.4% | 1.0% |
| No limit | 8192 | 0.8% | 2.2% | 0.3% |
| Disk 10 km | 32 | 11.5% | 33% | 3.4% |
| Disk 10 km | 512 | 2.9% | 8.4% | 0.9% |
| Disk 10 km | 8192 | 0.7% | 2.3% | 0.2% |

Across 40 independent repeats at 32 draws, the ratio of estimated to exact totals averaged 1.003 (SD 5.5%); at 512 draws, 0.995 (SD 1.4%). At 8,192 draws, four seeds per kernel gave 0.994–1.002.

**Halves check.** Accumulating odd and even draws separately gives two independent half-estimates; their disagreement estimates the noise of a single run without any reference. On the *P. edulis* surface, two independent 32-draw runs agreed at ρ = 0.987 (current), 0.983 (flow potential) and 0.944 (normalized) at r = 200 km, consistent with the halves figures.

**Tiling.** With a local kernel every pair spans at most R, so pairs can be split among tiles by their first endpoint, each tile solved on its core plus a buffer, and the tiles' squared currents summed with no seams. Against the same pairs solved untiled (3 × 3 tiles, r = 50 km, habitat cells):

| Buffer | Median error | 95th pct | 99th pct | Time (2-core test machine) |
| --- | --- | --- | --- | --- |
| 50 km (1R) | 0.47% | 6.0% | 18% | 16 s |
| 100 km (2R) | 0.19% | 2.8% | 10% | 21 s |
| 150 km (3R) | 0.11% | 2.0% | 7% | 29 s |
| Untiled | — | — | — | 37 s |

A 2R buffer keeps truncation error well below sampling noise. The largest errors sit along narrow habitat strands beside large gaps and at fringe cells near the habitat threshold, where true current is near zero.

## Benchmarks vs Omniscape

On equal cores the dipole method was 10–23× faster than Omniscape at 2 km, and an estimated 10–15× at 330 m. All timings are on one 10-core MacBook Pro (68 GB RAM); the dipole method in R with Accelerate BLAS, Omniscape.jl through circuitscaper with its faster solver at each radius and Julia's compilation warmed up first.

**2 km grid** (0.73 M cells, 32 draws × 1e5 dipoles, map includes normalization):

| Radius (px) | Omniscape, 10 threads | Dipole, 10 workers | Speedup | Dipole, factorizations reused | Speedup |
| --- | --- | --- | --- | --- | --- |
| 25 km (15) | 72.9 s (block 1) | 5.5 s | 13× | 2.5 s | 29× |
| 50 km (30) | 48.0 s (block 3) | 4.9 s | 10× | 1.9 s | 25× |
| 100 km (60) | 92.3 s (block 5) | 5.0 s | 18× | 2.0 s | 46× |
| 200 km (120) | 115.6 s (block 11) | 5.0 s | 23× | 2.0 s | 58× |

Single-threaded Omniscape took 254 s (50 km) and 605 s (200 km), against 7–8 s for single-core dipole runs: 36–75× per core. Exact Omniscape (block 1) at 50 km took 558 s; its block-3 result matched it at ρ ≥ 0.999 on every layer, so practical block sizes are the fair comparison. The dipole method's time is flat in radius; its 10-worker draws took \~2 s, so most of a map is building circuits (1.5 s, R code) and two factorizations (1.5 s).

**Realistic scale, estimated** (330 m, 18.2 M cells, 50 km = 150 px radius). Omniscape was timed on a central crop six radii across (0.81 M cells, 3,032 target windows: 185 s) and scaled to the full box's 25,004 windows of 14% larger average size. Dipole-method parts were timed at 0.7–11.7 M cells and extrapolated.

| Method | Time | vs Omniscape |
| --- | --- | --- |
| Omniscape, 10 threads | ≥ 1,740 s | — |
| Dipole, untiled, 1 core | 492 s (≈ 340 s using the local growth rate) | 3.5–5× |
| Dipole, factorizations reused | 89 s | 20× |
| Dipole, 23 tiles of 1,500 px, 7 at once | \~110 s | 15× |
| Dipole, 10 tiles of 2,000 px, 4 at once | \~170 s | 10× |

Both estimates lean toward Omniscape: its figure scales cost only linearly in window size and the smooth resampled surface eases its iterative solver, while the dipole method's fitted factorization growth (cells^1.64) is steeper than measured between 3× and 4× (cells^1.13). Factorization memory at 330 m: \~13 GB, 1.7 billion nonzeros, under the 2.15 billion limit of 32-bit indices.

## Benchmarks vs pairwise Circuitscape

On the same focal nodes, random dipoles took about 3 s from 25 to 1000 nodes while pairwise Circuitscape's time grew with the square of the node count, reaching 774 s at 200 nodes.

&#91;embedded content: sandbox/pairscape\_pairwise.R on a 10-core MacBook Pro, one core per method; R methods include the shared 2.3 s graph and factorization; Circuitscape at 1000 nodes extrapolated at its measured 39 ms per pair\]

Nodes were drawn in proportion to suitability on the 2 km surface. Random dipoles over nodes used 32 draws, each weighting every pair by an independent normal; the exact method used the N-solve identity. Circuitscape's pairwise mode can split pairs across threads, which might cut its times 5–8× on 10 cores; that still leaves roughly 30–50× at 200 nodes.

| Nodes | Random dipoles vs exact squared (ρ) | Median error per cell | Exact squared vs Circuitscape (ρ) | Random dipoles vs Circuitscape (ρ) |
| --- | --- | --- | --- | --- |
| 25 | 0.998 | 7.7% | 0.997 | 0.997 |
| 50 | 0.999 | 9.0% | 0.997 | 0.996 |
| 100 | 0.997 | 5.8% | 0.986 | 0.980 |
| 200 | 0.999 | 6.7% | 0.983 | 0.980 |

The random-dipole method reproduces the exact squared answer at every N (also ρ 0.999 at 500 and 1000 nodes). Squaring is the only real difference from Circuitscape; it grows slightly with N, as more pairs' flows overlap and squaring weights the strongest corridors more.

## Fast exact pairwise

*Scope: package feature only. This is Brandes and Fleischer's (2005) known algorithm applied to Circuitscape (see Related work), so it is not planned for the paper beyond, at most, a mention where the software is described.*

Pairwise Circuitscape factors the circuit once but still solves it once per pair, N(N−1)/2 solves for N nodes. If only the cumulative current map is wanted, not per-pair maps or resistances, N solves are enough. By superposition, the voltages for the pair i → j are the voltages with i as the source minus those with j as the source, both measured against a common reference node. On each link, let y\_i be its current when node i is the source. Circuitscape's cumulative current on that link is the sum of |y\_i − y\_j| over all pairs, which equals a weighted sum of the link's N values in sorted order:

```latex
\sum_{i<j} |y_i - y_j| = \sum_{k=1}^{N} (2k - N - 1)\, y_{(k)}
```

So each link costs a sort of N numbers instead of N(N−1)/2 differences. Cell values then follow Circuitscape's convention: half the sum over the cell's links, plus (N − 1)/2 at each focal node, because Circuitscape also counts the unit injected or withdrawn in every pair that node joins.

This is the same computation as Circuitscape, not an approximation. On the 2 km *P. edulis* surface with the same 200 nodes:

- the median ratio to Circuitscape is 1.00004;
- 99% of cells are within 0.5%, and focal-node cells match exactly;
- the only larger differences are in non-habitat cells that carry about 2 × 10⁻⁷ of the total current.

On the 10-core MacBook Pro, in one R process, fast exact pairwise took 2.8 s at N = 25, 13 s at 100, 33 s at 200, 74 s at 500 and 149 s at 1000, plus 2.1 s of shared graph building and factorization. Agreement with Circuitscape was the same at every N it was run (median ratio 1.00004–1.00005, 99.0–99.1% of cells within 0.5%). That is 3× faster than Circuitscape at 25 nodes, 13× at 100 and 22× at 200, and the gap keeps widening: at Circuitscape's measured 39 ms per pair, 1000 nodes would take it about 5.4 hours, against 2.5 minutes. Time grows roughly linearly in N, and about 80% of it is the per-link sorts, single-threaded R code that is easy to parallelize or compile. Memory does not shrink: all N voltage vectors are held at once, 5.4 GB at N = 1000 on this grid. For much larger N, or when absolute current is not required, the random-dipole method is cheaper still (about 3 s at any N).

**Ground floor.** Exact agreement needed a smaller floor on the matrix diagonal, the tiny conductance to ground at every node that keeps the matrix positive definite. At 10⁻⁸ per node, the floor drained enough current to put low-conductance cells 10–25% off Circuitscape; at 10⁻¹² or 10⁻¹⁵ the results match and the factorization is still stable. `dipole.R` now defaults to 10⁻¹². Dipole maps made before this change used 10⁻⁸, so their non-habitat values are slightly off; habitat values are essentially unaffected.

## Sources, grounds and dipoles

For a single pair, two setups give identical currents:

- a unit current source at i with j grounded;
- +1 injected at i and −1 at j, with no ground.

In both, one unit enters at i and leaves at j, and Kirchhoff's laws fix the flow between them. The two setups only behave differently when many endpoints are active at once.

A ground is a conductance to zero volts. How much current it takes depends on its voltage, and that voltage depends on everything else in the circuit. So current drains to whichever grounds are electrically nearest, and adding a ground changes the matrix. A negative source is a fixed withdrawal: it takes exactly its amount wherever the current comes from, and the matrix stays the same.

Every dipole method relies on fixed withdrawals. With injections fixed in advance, superposition lets one solve carry many pairs, and random signs make the cross-pair terms average out. With grounds, nothing records which source sent current to which sink. The solve then answers where current exits, not how much flows between i and j.

Random signs also assume the question is symmetric: flow from i to j counts the same as flow from j to i. That holds for pairwise and Omniscape current maps, but not for oriented flows such as present to future habitat.

## Cross-era connectivity

TreeShift's range-shift layer uses Circuitscape advanced mode on the following circuit:

- present habitat as current sources summing to 1;
- future habitat as grounds;
- conductance √(present × future) scaled to mean 1, plus 10⁻³.

Two alternatives from the dipole family were prototyped on the same 2 km *P. edulis* surfaces (SSP5-8.5, 2041–2070).

**Net flux (oriented).** Present habitat injects, and future habitat withdraws, fixed amounts that each sum to 1. It takes one solve and answers how the range as a whole moves, with direction. Which present cell pairs with which future cell does not matter, only the cell totals do, so a dispersal kernel can act only by changing those totals. Where present and future suitability are similar, injection and withdrawal cancel and the cell carries little current.

**Gross pathways.** Random-sign dipoles, with one end drawn from present habitat and the other from future habitat, either within a dispersal radius (100 km tested) or anywhere. This answers which pathways carry present-to-future movement within reach. Both directions count, so it gives magnitude only, with no direction. It costs the same 32 draws as other random-dipole maps.

Spearman correlations among the four maps, on habitat cells:

|  | Net flux | Gross, 100 km | Gross, no limit |
| --- | --- | --- | --- |
| Advanced mode | 0.84 | 0.69 | 0.79 |
| Net flux |  |  | 0.90 |
| Gross, 100 km |  |  | 0.92 |

Visually, advanced mode shows halos of current around habitat. Net flux reaches distant patches, such as those in the southeast, and is dark where present and future habitat coincide. The 100 km gross map is the most local of the three.

**The app's "no loss" setting leaks.** With loss set to "none", the app still grounds every cell at 10⁻⁶. Summed over 728,000 cells, that is about 0.73 of conductance to ground, against target grounds totalling 1. In the default P. edulis run, 27.5% of the current exits through this floor rather than through future habitat. That leakage likely explains much of the halo pattern. Using a much smaller floor (10⁻¹² works here), or one scaled to the cell count, would make "none" lossless in practice.

## Questions and operations

The operations differ along three axes:

- **Output:** gross (current magnitude) or net (signed current, with direction).
- **Pairing:** symmetric or one-way.
- **Weights:** binary (a pair counts or not) or continuous.

Omniscape covers gross output with symmetric pairing, or one-way binary pairing through conditional connectivity. The dipole methods cover the rest; net output is the part no existing tool offers.

For range shifts, it helps to split habitat into three zones by present and future suitability:

- **L (lost):** suitable now but not in the future.
- **S (stable):** suitable in both.
- **G (gained):** suitable only in the future.

Each question is then a choice of which zones the pairs connect, how they are weighted, and which output is wanted. Prototypical single-species questions:

| Era | Question | Pairs | Output | Operation |
| --- | --- | --- | --- | --- |
| Within | Where does dispersal-limited movement among habitat concentrate? (demographic connectivity, metapopulation persistence) | Habitat × habitat × dispersal kernel | Gross | Random dipoles, local kernel (Omniscape's role) |
| Within | Which corridors carry gene flow among populations? (isolation by resistance) | Focal populations, all pairs | Gross; effective resistances | Fast exact pairwise |
| Within | Where does emigration from productive habitat go? (source–sink dynamics) | High-productivity habitat → low-quality habitat, one-way | Net | Oriented dipoles |
| Within | Which corridors connect climatically different populations? (exchange of standing adaptive variation) | Weight increasing with environmental distance | Gross | Random dipoles, continuous weights |
| Shift | Is the stable core connected to itself? (persistence) | S × S | Gross | Random dipoles |
| Shift | Where are the escape routes from the trailing edge? (contraction) | L → S ∪ G | Gross; net for where retreating populations converge | Random and oriented dipoles |
| Shift | Which pathways feed colonization of new habitat? (expansion) | S ∪ L → G | Gross for pathways; net for expansion fronts | Random and oriented dipoles |
| Shift | Where can pre-adapted alleles reach the places they will be needed? (adaptive gene flow) | Source's present climate ≈ target's future climate, continuous similarity weight | Gross; net for direction | Random and oriented dipoles (conditional Omniscape is the binary version) |
| Shift | How does the range as a whole move? (displacement) | All present habitat → all future habitat | Net | One solve: fixed withdrawals, or grounds as in Circuitscape advanced mode |

**Grounds and dipoles answer different displacement questions.** With grounds (TreeShift's advanced-mode model), current exits wherever ground conductance is high and voltage still elevated, so most of it drains into the nearest future habitat. Stable cells are both sources and grounds and absorb their own current locally. The question answered is where the range goes if it settles in the first suitable habitat it reaches. How far it reaches depends on the ground-strength scale, which acts as an implicit and uncontrolled dispersal limit. With fixed withdrawals (net flux), every future cell must take its full share however far away it is, so current is pushed through to the interior of G and to distant patches. The result is the minimum-energy flow that turns the present distribution into the future one, and the question is how the range must redistribute to match its future distribution.

**Net flux is mostly L → G.** Stable cells inject and withdraw similar amounts, which cancel, so present-to-future net flux over all habitat reduces largely to flow from lost to gained habitat. That is why the prototype net-flux map is dark where present and future habitat overlap: it measures displacement, not persistence. Gross pathways keep stable cells as endpoints.

**Gross and net are biologically distinct.** Gross answers which routes matter if movement happens; net answers which way movement goes and where it converges. For contraction and expansion both are useful, and their ratio, a directionality index, says whether a corridor is a one-way escape route or two-way exchange.

**Continuous weights matter most for adaptive gene flow.** A climate-match tolerance is a strong, arbitrary choice, and a similarity kernel removes it. The within-era mirror image, weighting pairs by climatic difference to find corridors that mix divergent populations, has no Omniscape equivalent.

**Management.** Persistence connectivity supports resisting change; contraction escape routes and expansion corridors are where directing it would act, through corridor protection or by showing where assisted migration would stand in for missing pathways.

**Caveats.** Zone membership depends on a suitability threshold; continuous weights soften that, but results should show sensitivity to it. Net flux has no dispersal limit, because it sees only cell totals, so directional results are best shown beside a dispersal-limited gross map.

## How the random-dipole method differs from Omniscape

The remaining gap to Omniscape is structural, not noise: the random-dipole method converges to a different quantity. Agreement with Omniscape fell with radius (current ρ 0.982 at 25 km to 0.948 at 200 km; flow potential 0.990 to 0.909; normalized 0.870 to 0.858), while the method's own run-to-run agreement stayed high.

| Candidate cause | Test (at 100 and 200 km) | Result |
| --- | --- | --- |
| Sampling noise | Two independent 32-draw runs; 64 draws | Runs agree at ρ 0.987 / 0.983 / 0.944 but match Omniscape at only 0.945 / 0.905 / 0.845; 64 draws barely moves it. Not noise. |
| Pair weighting | Omniscape-style: each target's total current = its own strength, shared among window sources | Worse at every radius (200 km: current 0.923 vs 0.945, flow potential 0.832 vs 0.902). Not the cause. |
| Kernel shape | Pixel-unit circle (Omniscape's window) instead of a km circle, an ellipse on this lon/lat grid | Gains of ≤ 0.01. Minor. |
| Within-window summing | Coherent stars: each target's whole window circuit as one random-signed unit (one FFT convolution per draw) | Normalized improves (100 km: 0.868 to 0.905), current and flow potential get worse. Partial. |
| Squared vs absolute current | Not isolated yet | Likely main cause; squaring weights strong convergent flow heavily |
| Window truncation | Not isolated yet | Omniscape solves each target inside its window; the dipole method on the whole grid |

The last two could be separated exactly on a small grid by computing pairs vs stars, squared vs absolute, and a true window-truncated Omniscape. For the paper, the random-dipole method is best presented as its own well-defined quantity (kernel-weighted pairwise squared current on the untruncated circuit), validated exactly against that definition, with Omniscape as the closest comparison.

**Absolute current with Cauchy weights.** Weighting each dipole by a standard Cauchy variable instead of a random sign makes each link's current Cauchy-distributed, with scale equal to the sum of the pairs' absolute currents. Since E log|Cauchy(0, s)| = log s, averaging log|current| over draws estimates Circuitscape's absolute quantity rather than the squared one. On 200 focal nodes it converges to pairwise Circuitscape (ρ 0.979 at 32 draws, 0.999 at 512), where the squared version levels off near 0.94. Within a run the pattern is accurate, but the whole map's level varies between runs (median ratio 0.96–1.17 at 128 draws across seeds), because a draw's largest weights shift every link together.

Over six seeds on the 200 focal nodes, the map level is unbiased (mean ratio to Circuitscape 1.01 at every draw count). Its spread falls as 1/√draws: SD 0.26 at 32 draws, 0.095 at 128 and 0.044 at 512. Within-map noise (median absolute deviation of the log ratio) falls at the same rate, from 0.19 to 0.10 to 0.05. So the level noise is ordinary correlated sampling noise, not a bias, and it needs no special fix. Reaching the squared estimator's precision at 32 draws takes roughly ten times as many Cauchy draws.

In Omniscape-like mode (10⁵ dipoles per draw, Spearman ρ against Omniscape on habitat cells):

| Radius | Weights | Draws | Current | Flow potential | Normalized |
| --- | --- | --- | --- | --- | --- |
| 50 km | Random signs (squared) | 32 | 0.977 | 0.982 | 0.877 |
| 50 km | Cauchy (absolute) | 128 | 0.942 | 0.895 | 0.711 |
| 200 km | Random signs (squared) | 32 | 0.947 | 0.906 | 0.862 |
| 200 km | Cauchy (absolute) | 128 | 0.958 | 0.950 | 0.910 |

The Cauchy maps' run-to-run agreement at 128 draws is 0.98–0.996, so these gaps are structural, not noise. Absolute current brings the method closer to Omniscape at 200 km but further away at 50 km. A likely explanation is that the two remaining differences interact. On the whole circuit, each pair's current spreads thinly far beyond Omniscape's window; absolute current weights that diffuse tail more heavily than squared current, which suppresses it and so partly mimics window truncation. At 200 km the windows cover much of the domain and truncation matters less. This is a hypothesis to test with a window-truncated variant. The map-level noise largely cancels in the normalized layer (median level ratio 0.97–1.01 between runs, against 0.93–0.97 for current), since current and flow potential share the same weights.

**Exact decomposition.** On a 64 × 64 crop of the 2 km surface (2,620 habitat targets), every combination of five design choices was computed exactly at radii of 6 and 12 pixels:

- pairs vs per-target stars;
- squared vs absolute current;
- whole circuit vs Omniscape's circular window;
- product pair weights vs Omniscape's per-target normalization;
- flow potential on the same shape as the current circuit vs Omniscape's uniform square box.

The reference is an exact R reimplementation of Omniscape (block size 1). Against a real `os_run` on the same crop it matches at ρ ≥ 0.9999 on all three layers, with a median cell ratio of 1.00000; the few cells off by more than 0.5% are low-current cells near the crop edge. The match requires counting half the injected current at each source and target cell, as Circuitscape's cell current does. Spearman ρ of the normalized layer against it, on habitat cells, at R = 12:

| Configuration | Normalized ρ |
| --- | --- |
| Random-dipole method (pairs, squared, whole, product) | 0.845 |
| … with absolute current | 0.587 |
| … with window truncation | 0.836 |
| … with absolute current and window truncation | 0.961 |
| … plus Omniscape weights | 0.985 |
| … plus stars | 0.992 |
| … plus square flow-potential box (Omniscape) | 1.000 |

R = 6 gives the same pattern, and the current layer agrees at ρ ≥ 0.96 in every configuration. The normalized gap comes almost entirely from absolute current combined with window truncation: neither helps alone, and absolute current on the whole circuit is much further from Omniscape than squared current. On the whole circuit, each pair's current spreads thinly across the domain. Summed in absolute value over many pairs, that diffuse background is large in both current and flow potential, and their ratio is dominated by it. Omniscape's windows cut it off, and squaring suppresses it. Weights, stars and the flow-potential box shape together account for the last \~0.04. Whether truncation is a desirable property or an artifact of Omniscape's moving window is an ecological question, taken up separately.

**Far-field current.** On the whole circuit, 26–52% of summed absolute pair current lies on links more than R from the pair's target (R = 12 and 6 px; the uniform circuit is at the high end), against 4–8% of summed squared current. This background is what absolute current on the whole circuit adds and squaring suppresses. On the crop it washes out the narrow channel features that Omniscape's normalized layer and the squared whole-circuit layer both show.

**Scalable truncation recovers only part of the gap.** Normalized ρ against Omniscape, absolute current with Omniscape weights:

| Truncation | R = 6 | R = 12 |
| --- | --- | --- |
| None (whole circuit) | 0.704 | 0.729 |
| Uniform leak to ground, decay length R/2 | 0.921 | 0.878 |
| Tiles: core R, buffer R | 0.937 | 0.903 |
| Exact per-target window (Omniscape) | 0.978 | 0.985 |

With product weights the scalable versions reach only 0.74–0.88. Leak and tiles do not help squared current (0.81–0.88, against 0.85 untruncated).

**Truncation is an artifact in a barrier test.** In a toy landscape, two habitat bands lie on either side of a three-cell-thick barrier (conductance 10⁻⁶) with a gap beyond the radius (R = 10). On the whole circuit, 97–98% of the current crossing the barrier row goes through the gap. The gap is a strong pinch point (normalized 5–15), and the barrier has normalized current 0.02–0.09. In Omniscape, the detour leaves every window, so the fixed injected current is forced through the barrier: 1% goes through the gap, and the impermeable barrier shows normalized current 0.46, as if it were semi-permeable. Absolute current with window truncation behaves the same (0.35).

**Omniscape's square flow-potential box is a second artifact.** In the same toy's homogeneous matrix, where normalized current should be 1, Omniscape gives 0.33 in the outer ring 7–10 px from habitat. The cause is that flow potential spreads over the square box while current is confined to the circle. With a circular flow-potential circuit the ring is 1.00, and the habitat interior is 1.01 either way.

**False corridor at a weak spot.** The same barrier was given a weak spot inside the window radius, still 1,000 times less permeable than the matrix (conductance 10⁻³), with the real gap beyond the radius. Omniscape sends a third of the barrier-crossing current through the weak spot and gives it normalized current 1.94, so it reads as a corridor. On the whole circuit the weak spot carries 1–4% of the crossing current (normalized 0.11–0.24), and the gap carries 57–86% (normalized 5–15).

**Corridor through poor matrix.** Two habitat blocks sit 8 cells apart across matrix of conductance 0.02, joined by a 2-cell corridor. Results:

- **Squared current, whole circuit:** 52% of the crossing current uses the corridor, which has normalized current 1.61.
- **Absolute current, whole circuit:** 28% and 0.73.
- **Omniscape:** 17% and 0.54.

Under truncation, pairs far from the corridor cannot detour to it inside their windows and are forced straight through the matrix. Squared current also weights concentrated flow more heavily than absolute current does, which sharpens corridors and pinch points.

**Study-area edges.** Trimming 8 cells from every side of the crop and comparing with the full crop (R = 6) measures edge sensitivity. The table gives the median |log ratio| of normalized current on habitat cells, by distance from the trimmed edge:

| Method | 1–3 cells | 4–6 | 7–9 | 13+ |
| --- | --- | --- | --- | --- |
| Omniscape | 0.020 | 0.006 | 0.003 | 0.000 |
| Random dipoles (squared, whole) | 0.022 | 0.005 | 0.002 | 0.001 |
| Absolute, whole | 0.061 | 0.030 | 0.021 | 0.009 |

The whole circuit is no more edge-sensitive than Omniscape with squared current. With absolute current, the far-field background carries edge effects deep into the interior.

**Full-scale check: truncation explains little of the real gap.** Omniscape was run at 50 km (30 px, block 3) on the full 2 km surface twice: as usual, and with a buffer of one radius, which extends each circuit beyond the source window and so lifts most of the truncation. That allows a test of whether the cells where the random-dipole map (256 draws) disagrees with Omniscape are the cells where truncation matters. Comparisons use normal scores of ranks on habitat cells.

- **Buffering changes Omniscape modestly.** Normalized ρ between the buffered and unbuffered runs is 0.951, and it does not move Omniscape toward the dipole map (ρ 0.881 unbuffered, 0.872 buffered).
- **Disagreement only partly tracks truncation.** The cell-level disagreement correlates with the truncation shift at r = 0.26 for the normalized layer and 0.49 for flow potential. With the squared-vs-absolute contrast (dipole minus Cauchy map) added, the two explain 25% of the disagreement.
- **The gap is a thin margin effect.** Mean absolute disagreement is 0.65 normal-score units within 2.5 km of non-habitat (suitability below the 0.01 source threshold), against 0.16–0.24 beyond 10 km. It is largest in the lowest-suitability habitat cells. Away from the margins the maps agree better: normalized ρ 0.926 beyond 5 km from non-habitat (79% of habitat cells) and 0.936 beyond 10 km.

So lifting truncation alone does not bring Omniscape toward the dipole map, and most of the full-scale difference sits at habitat margins. The margin tests below trace that band to the same interaction of absolute current and window truncation. Script: `dipole_truncation_omniscape.R`; the analysis scripts are not yet in the repo.

**Margin tests.** Four candidate causes of the margin band were tested:

- **Cell aggregation rule: not the cause.** Turning link currents into cell values as the RMS (current method), as summed link RMS (Circuitscape's form), or with half the injected current added leaves the margin band unchanged at full scale: mean |disagreement| 0.65–0.70 within 2.5 km, 0.20 beyond 10 km.
- **Omniscape's block size: not the cause.** Block 3 and exact block 1 differ by at most 0.04 anywhere, and the dipole map's margin band against each is identical.
- **Hard source threshold: not the cause.** On the crop, rerunning every configuration exactly with no threshold, so that every cell is a source in proportion to suitability, leaves the band unchanged (0.75 vs 0.71 in the edge cells).
- **Omniscape weights: partly.** At full scale they reduce the edge band (0.53) but worsen agreement in the interior (0.24 beyond 10 km).

The exact factorial reproduces the band with the same magnitudes as full scale: 0.65–0.71 in cells next to non-habitat, falling to 0.20–0.22 six or more cells in. Mean |disagreement| with exact Omniscape by cells from non-habitat, R = 12 px:

| Configuration | ≤1 | 2–3 | 4–6 | >6 |
| --- | --- | --- | --- | --- |
| Random-dipole method | 0.65 | 0.35 | 0.35 | 0.22 |
| … with absolute current | 1.14 | 0.92 | 0.69 | 0.50 |
| … with window truncation | 0.52 | 0.43 | 0.37 | 0.30 |
| … with Omniscape weights | 0.55 | 0.48 | 0.45 | 0.34 |
| … with absolute current and windows | 0.24 | 0.21 | 0.18 | 0.13 |
| … plus Omniscape weights | 0.11 | 0.09 | 0.11 | 0.09 |

The margin band is therefore the same joint effect of absolute current and window truncation, with Omniscape's weights, that separates the methods everywhere; it is simply largest at habitat edges, where conductance drops sharply. The additive full-scale regression understated it because the effect is an interaction: removing truncation alone (the buffer) or switching to absolute current alone each moves away from the dipole map.

**Provisional reading.** Omniscape's normalized layer depends on window truncation, which forces current through barriers whose detours leave the window, and on a box-shape mismatch that darkens the edge of its reach. Absolute current without truncation is dominated by far-field background. Squared current on the whole circuit, the random-dipole method as it stands, avoids all three problems and keeps the channel structure.

## Feature parity and extensions

Most Omniscape options carry over directly; conditional connectivity is a change to the pair sampler; direction is the one output dipoles cannot give.

| Omniscape feature | In the dipole methods | Notes |
| --- | --- | --- |
| Separate source strength and resistance | Done | Independent inputs to `dp_connectivity()` |
| Sources from resistance, `r_cutoff`, `source_threshold` | Trivial | Preparing the source layer |
| Resistance or conductance input, reclassification, NoData | Trivial | Input preparation |
| 4- vs 8-neighbour graph, conductance averaging | Trivial | One option in `dp_graph()` |
| Radius | Done | Disk kernel; any kernel shape (e.g. negative exponential) is a sampler change |
| Flow potential and normalized current | Done | Same dipoles on a uniform circuit |
| Conditional connectivity (`equal`, `within`, present vs future) | Straightforward | An accept/reject test on each proposed partner; strict conditions need per-class or binned candidate lists to keep sampling fast |
| `block_size` | Not needed | Cost does not depend on the number of targets |
| Multithreading | Different | Parallel draws or tiles; linear algebra via the BLAS |
| Current direction | Not available | Random signs discard direction; an oriented solve (like TreeShift's cross-era model) is still needed for direction maps |

Beyond Omniscape: a no-limit kernel (pairwise semantics over all habitat cells), cheap radius sweeps on one factorization, and a built-in error estimate. Present-vs-future conditional pairs would give a fast climate-tracking connectivity layer, so one engine could serve both TreeShift's within-era and cross-era questions.

## Roadmap: operations and features

The dipole approach is growing from one function into a family of operations that share one engine: a circuit factored once, and a choice of which pairs to weight and how to combine them. Status: done = prototyped and tested here; planned = design clear, not built; idea = worth exploring.

| Area | Feature | What it does | Status |
| --- | --- | --- | --- |
| Operations | Omnidirectional | Local kernel over habitat-weighted cells; Omniscape's role | Done |
| Operations | All-pairs | No distance limit over all habitat cells; pairwise semantics without node choice | Done |
| Operations | Focal-node pairwise | Every pair of N nodes, random-weighted per draw; plus the exact N-solve squared version | Done |
| Operations | Fast exact pairwise | Pairwise Circuitscape's cumulative current map exactly, from N solves and a sort per link | Done (prototype) |
| Operations | Region-to-region | Pairs restricted to source region A and target region B (protected area to protected area, one region to all others) | Planned |
| Operations | Cross-era gross pathways | Random-sign pairs from present to future habitat within dispersal reach; magnitude, no direction | Prototyped |
| Operations | Cross-era net flux | Oriented present-to-future flow with fixed sinks; one solve, gives direction; kernel acts only through cell totals | Prototyped |
| Operations | Zone pairing | Pairs restricted by lost, stable and gained habitat zones (contraction, expansion, persistence) | Planned |
| Outputs | Directionality index | Net over gross current from the same pair weights: one-way vs two-way corridors | Idea |
| Operations | Conditional pairs | Pairs kept only if a condition holds (same class, within a range, present matching future climate) | Planned |
| Operations | Multispecies | Several species' pair distributions on one shared resistance surface, at the cost of one map | Idea |
| Operations | Resistance distances | Pairwise effective resistance among sites (isolation by resistance); exact from N solves, random projections for very large N | Idea |
| Kernels | Kernel shapes | Disk, Gaussian, negative exponential, user-supplied | Planned (disk done) |
| Kernels | Directional kernels | Asymmetric, e.g. wind-driven dispersal (links to windscape) | Idea |
| Kernels | Pair-weight options | Product weighting (default) or Omniscape-style per-target normalization | Done (tested) |
| Kernels | Absolute current | Cauchy dipole weights estimate summed absolute pair current, Circuitscape's quantity, instead of squared | Prototyped (map level noisy) |
| Outputs | Current, flow potential, normalized | RMS current; same pairs on a uniform circuit; their ratio | Done |
| Outputs | Pinch points | Current squared times resistance per link: expected power dissipation, Circuitscape's pinch-point measure | Planned |
| Outputs | Connectivity classes | Channelized, diffuse, impeded, from normalized current and a flow-potential floor | Planned |
| Outputs | Uncertainty map | Per-cell error from odd vs even draws | Planned (diagnostic done) |
| Outputs | Direction | Bearing of net flow, from the oriented net-flux operation only | Planned |
| Engine | Factorization reuse | Prepare a circuit once, then run many kernels, sources or conditions on it | Planned |
| Engine | Tiling | Local kernels on grids too big to factor whole; 2R buffers | Done (prototype) |
| Engine | Parallel draws | Draws split across workers sharing the factorization | Done (prototype) |
| Engine | Progressive refinement | Show a map after a few draws, refine to a target error | Idea |
| Engine | Native implementation | Julia with 64-bit indices and threads, built on Circuitscape.jl's graph construction and solver backends so it can move upstream later; exposed in circuitscaper beside cs\_\* and os\_\* | Planned |
| Engine | Iterative solver | Multigrid with many right-hand sides for very large grids | Idea |
| Engine | Variance reduction | Deflation or structured probes to need fewer draws | Idea |
| Validation | Exact checker | Small-grid brute-force comparison as a package test | Done (script) |

## Related work and novelty

A first literature pass (November 2026), not exhaustive. Its main result is that two of our core pieces are known in network science under other names. That weakens a claim of algorithmic novelty but strengthens the theory behind the methods.

**Fast exact pairwise is Brandes and Fleischer's exact algorithm for current-flow betweenness.** [Brandes & Fleischer (2005)](https://algo.iti.kit.edu/_media/projects/spp1126/files/bf-cmbcf-05.pdf) compute the potentials once and then, for each edge, sort the per-vertex values and take a rank-weighted sum instead of enumerating pairs. That is exactly our sort identity, with time O(I(n−1) + mn log n). Current-flow betweenness is also Newman's random-walk betweenness, and a subset version, restricted to focal nodes, is implemented in [NetworkX](https://networkx.org/documentation/stable/_modules/networkx/algorithms/centrality/current_flow_betweenness.html). [Circuitscape's documentation](https://docs.circuitscape.org/Circuitscape.jl/v5.15/usage) already notes that pairwise resistances need only n solves when no current or voltage maps are written, but that mapping currents needs n(n−1)/2. Our contribution is therefore applied, not algorithmic: the known algorithm computes Circuitscape's cumulative current map exactly, at 13–130× the speed.

**Squared current is a gradient of effective resistance.** For a unit flow between i and j, the derivative of their effective resistance with respect to a link's resistance equals the squared current through that link. This is a standard consequence of Thomson's principle; see section 2.4 of [Christiano et al. (2010)](https://arxiv.org/pdf/1010.2921). So the random-dipole quantity, Σ pᵢⱼ Iₑ(i,j)², is the sensitivity of the kernel-weighted total pairwise resistance among habitat to degrading link e. In ecological terms, it says how much connectivity among habitat within reach would suffer if that link got harder to cross. With uniform weights over all node pairs it is the edge gradient of the Kirchhoff index, which [Ghosh, Boyd & Saberi (2008)](https://web.stanford.edu/~boyd/papers/pdf/eff_res.pdf) use to optimize networks. [Li & Zhang (2018)](https://arxiv.org/pdf/1708.05959) and [Yi et al. (2018)](https://www.ijcai.org/proceedings/2018/503) propose it as an edge centrality and estimate it in nearly linear time with Johnson–Lindenstrauss random projections, the same estimator family as random dipoles. Two existing ecological uses connect to it:

- mean pairwise effective resistance as a network connectivity indicator ([O'Brien et al. 2023](https://peerj.com/articles/16333));
- restoration prioritization by the improvement in resistance when a barrier is removed (McRae et al. 2012, "Where to restore ecological connectivity?", PLoS ONE).

This gives squared current a principled interpretation, which absolute current lacks, and answers the question of why squared rather than absolute.

**Cauchy weights are Indyk's stable-distribution sketch.** Estimating an L1 norm from random linear combinations with 1-stable (Cauchy) weights is [Indyk (2006)](https://cs.au.dk/~gerth/madalgo/old-madalgo.au.dk/img/SumSchoo2007_Lecture%20slides/Bibliography/p3-Indyk_JACM_06.pdf); estimator choices are compared by [Li (2006)](https://arxiv.org/pdf/cs/0610155).

**Omnidirectional methods in landscape ecology.** Three methods are established:

- random point nodes around a buffered perimeter ([Koen et al. 2014](https://zendy.io/title/10.1111/2041-210x.12197));
- wall-to-wall tiles ([Pelletier et al. 2014](https://www.peeref.com/works/14923438));
- Omniscape's moving window ([Landau et al. 2021](https://joss.theoj.org/papers/10.21105/joss.02829)).

[Phillips et al. (2021)](https://www.x-mol.com/paper/1388880060400820224) compared all three and found their current maps highly correlated except on uniform grids, where each showed its own node-placement bias; the main differences were computational. None of these approaches uses superposition or random projections, and none is defined as an explicit kernel-weighted pair quantity.

**What still looks new.** Nothing in this pass covers the following:

- a local, kernel- and habitat-weighted pair distribution sampled into random-sign dipoles, which extends the uniform all-pairs random-projection estimators to dispersal-limited connectivity;
- its use on raster landscapes, with flow-potential normalization, as a fast, unbiased alternative to Omniscape;
- the diagnosis of Omniscape's window-truncation and box-shape artifacts;
- the cross-era operations (net flux, gross pathways, zone pairing).

A deeper search, through Google Scholar and the citations of Li & Zhang and Phillips et al., should come before submission.

## Limitations and open questions

- **Different quantity.** Squared rather than absolute current, on the whole circuit rather than truncated windows. Ranks agree closely with pairwise Circuitscape (ρ 0.98–0.997) but less with Omniscape's normalized layer (ρ ≈ 0.86).
- **Stochastic.** About 6–12% noise per cell in current and 3–10% in the normalized layer at 32 draws; the normalized layer gets noisier as the radius grows (halves difference 0.05 at 25 km, 0.10 at 200 km). Halving the error costs 4× the draws.
- **Dipoles at fine grain.** The default of 1e5 dipoles per draw was tuned at 0.73 M cells; at 330 m each cell gets 25× fewer dipole endpoints. Whether that needs more dipoles is untested.
- **Factorization at scale.** Grows as roughly cells^1.1–1.6. A single 90 m state-wide grid (\~1e8 cells) won't factor in one piece; R's sparse matrices also cap a factorization at 2.15 billion nonzeros. Tiling handles local kernels; the no-limit kernel cannot be tiled.
- **Smooth test surface.** All benchmarks use a suitability surface smoothed by TreeShift's 30 km bandwidth. Real land-cover resistance with sharp barriers is untested, both for agreement and for Omniscape's solver times.
- **No direction.** Random signs discard flow direction.
- **Novelty.** The random-projection estimator family is established in numerical linear algebra; its use for landscape current-density maps needs a proper literature search before claiming it as new.
- **BLAS matters.** On R's reference BLAS the factorization was 8× slower than with Accelerate; deployment servers need an optimized BLAS for these timings.

## Next steps

- [ ] Decompose the Omniscape gap exactly on a small grid: pairs vs stars, squared vs absolute current, window-truncated vs whole circuit
- [ ] Check dipoles per draw at 330 m with the halves diagnostic before any fine-grain speed claim
- [ ] Benchmark on a real land-cover or human-modification resistance surface at 270–300 m, with tiled random dipoles against Omniscape
- [ ] Run pairwise Circuitscape with its pair-level threading, so the pairwise comparison is on equal cores
- [ ] Literature search on stochastic estimators of current density and on omnidirectional connectivity methods
- [ ] Implement in circuitscaper (e.g. `ps_run()` beside `cs_*()` and `os_*()`), natively in Julia with 64-bit indices, tiling and parallel draws
- [ ] Add conditional pairs (`os_condition()`-style), including present-vs-future climate matching
- [ ] Turn the small-grid exact check into a package unit test
- [ ] TreeShift: within-era connectivity layer on Update, with the uniform-circuit factorization cached per box and grain
- [x] Time fast exact pairwise on the 10-core machine at N = 25–1000 (`pairscape_fast_exact.R`)
- [ ] Rerun the earlier random-dipole maps with the 10⁻¹² ground floor
- [ ] TreeShift: make the cross-era "no loss" setting lossless (a 10⁻¹² floor, or one scaled to cell count)
- [ ] Decide which cross-era measure(s) TreeShift offers beside advanced mode: net flux, gross pathways, or both

## Scripts and outputs

All in the TreeShift repo's `sandbox/`, run from the project root; outputs under `sandbox/connectivity_bench/`. Every benchmark resumes where it stopped if rerun.

| Script | What it does |
| --- | --- |
| `dipole.R` | The method: `dp_graph()`, `dp_sample()`, `dp_injections()`, `dp_accumulate()`, `dp_connectivity()` |
| `dipole_connectivity.R` | Driver: P. edulis maps at r = 50 km and no limit, with comparison figure |
| `export_surface.R` | Writes `suitability.tif` and Omniscape r = 50 km layers |
| `dipole_check.R` | Exact small-grid check against the dense-inverse target |
| `dipole_tiling.R` | Tiled vs untiled truncation error |
| `dipole_weighting.R` | Omniscape-style vs product pair weighting |
| `pairscape_star.R` | Pixel-circle kernel and coherent-star tests |
| `pairscape_noise.R` | Run-to-run agreement vs agreement with Omniscape |
| `dipole_vs_omniscape.R` | Accuracy and timing across radii 25–200 km (`radius/`) |
| `pairscape_bench_fair.R` | Equal-core timing: random dipoles serial and parallel, Omniscape per solver (`fair/`) |
| `pairscape_scaling.R` | Realistic-scale estimates at 330 m (`scaling/`) |
| `pairscape_pairwise.R` | Random dipoles and exact squared current vs pairwise Circuitscape (`pairwise/`) |
| `pairscape_fast_exact.R` | Fast exact pairwise vs saved Circuitscape maps, N = 25–1000 (`pairwise/`) |
| `export_crossera.R` | Writes present and future surfaces and the app's advanced-mode result (`crossera/`) |
| `pairscape_crossera.R` | Net flux and gross pathways vs advanced mode, plus the leakage check (`crossera/`) |
| `dipole_factorial_omniscape.R` | Real Omniscape (block size 1) on the factorial crop, for validation (`factorial/`) |
| `dipole_factorial.R` | Exact factorial vs Omniscape, validation, leak and tile variants, barrier, weak-spot, corridor and edge tests, figures; code in `dipole_factorial/` (`factorial/`) |
| `connectivity_bench.R` | First benchmark: Omniscape, pairwise and wall-to-wall at 2 km |
