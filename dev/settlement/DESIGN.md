# Settlement methods: design note (draft)

Status: exploratory, 2026-11-24. Nothing here is decided, except that `dp_isolation()` became `dp_accessibility()`, with `accessible_area`, `target_area` and `conductance` layers (§6). Names below are as they were when written. The API layout in §6 is one idea among several. The prototype is in `prototype/` (plain R + Matrix, independent of the Julia engine), and every number below comes from its scripts.

## 1. Why this came up

`dp_isolation()` scores each cell by its effective `resistance` to the habitat within a radius. We wanted a per-cell connectivity measure that also responds to *how much* habitat is in reach, and kept bolting amount onto `resistance`:

- **`coverage`** (merged in #19): the focal mean of target strength.
- **`effective_coverage`**: coverage × R\*/R against an "ideal" reference landscape. It falls with radius by construction: TreeShift core-habitat medians dropped from about 9% at 25 km to 1% at 250 km.
- **`effective_area`**: never built. It fixed the radius normalization but still fell with radius for 8% of core cells (20 → 40 km, confirmed exactly).

The root problem is that `resistance` withdraws current from the targets in **fixed proportions**. That makes it blind to amount, and a bigger radius can make it worse, since current is forced out to distant, hard-to-reach habitat. Anything built on it inherits both problems.

## 2. Goals for an amount-aware per-cell measure

1. More habitat in reach means more connected.
2. Easier movement means more connected.
3. A longer dispersal reach never means less connected.
4. Absolute: comparable across reaches, resolutions and landscapes.
5. Computable well: unbiased, with known noise or exact, for every cell.
6. Explainable in one sentence.

## 3. What doesn't work

**Discounting each pair** (Hanski-style, Σⱼ tⱼ exp(−Rᵢⱼ/R₀)) meets goals 1–4 and 6 but fails goal 5.

With Gaussian link signs, E[cos(ω(yᵢ − yⱼ))] = exp(−Rᵢⱼ/R₀) exactly, so the sum is unbiased from two window sums per draw. But on the example landscape (radius 15, 64 draws, against a dense exact solve) it was far too noisy:

| R₀ | Median relative SE | 90th percentile | Spearman ρ with exact |
|---|---|---|---|
| 1 | 120% | about 10⁶ | 0.85 |
| 5 | 14% | 324% | 0.98 |

The engine estimates linear functionals of R well and nonlinear ones badly.

## 4. The settlement model

Dispersers released at a cell wander the circuit, preferring easy links as current does. They die at a constant rate everywhere, and settle in habitat at a rate proportional to its quality t. This is a spatial absorbing Markov chain (Fletcher et al. 2019, *Ecology Letters*; the `samc` R package).

**The circuit:** the landscape plus a ground at every cell for death, and a ground at habitat for settlement.

**Per-cell measure:** P(settle | released here). Inject current κt (amps) at the habitat; the voltage everywhere is P. That's one solve for all cells, exact, by reciprocity. A single `cs_advanced()` run (sources κt, grounds μ + κt as conductances) reproduces it to 5e-8. Resistance enters by slowing movement relative to death, so the reach shortens locally through barriers.

### Parameterization

On a grid of spacing h with 8 neighbours, L ≈ −(1+√2) h² ∇·(c∇). So:
- a rate per unit area *a* becomes a ground conductance of *a·h²* per cell;
- in terrain of conductance 1, the absorption position follows K₀(r/ℓ), with ℓ = √((1+√2)/a) and mean distance (π/2)ℓ.

Two **independent** distances:
- **`distance`**: the mean distance travelled before death, in terrain of resistance 1, without settling. It sets the death rate everywhere.
- **`settle_distance`**: the mean distance travelled through continuous quality-1 habitat before settling, without death. It sets the settlement rate, times t.

In continuous quality-1 habitat, the share that settle is distance² / (distance² + settle_distance²).

They must be independent. The first version used a fixed "settle share", which tied the settlement rate to the death rate. Then longer dispersal also slowed settlement, and about 1,700 cells' P *fell* with distance. With independent rates, a longer `distance` only lowers the death rate, so P can't fall (Rayleigh monotonicity).

## 5. Prototype findings

**Calibration** (`check_distance.R`). In uniform terrain, the mean distance at death equals `distance` to within 1%, for h from distance/40 to distance/5.

**Resolution** (`check_resolution.R`). The same synthetic landscape on 2, 1 and 0.5 km grids, at distance 10 km and settle_distance 2 km, aggregated back to 2 km:
- median |ΔP| 0.0007 (1 km) and 0.0010 (0.5 km); maximum 0.05.

**Reach.** On the 1 km grid, from 2.5 to 40 km, no cell's P fell. Median P rose 0.33 → 0.66 → 0.88 → 0.97 → 0.99. P **saturates** once `distance` is well beyond the spacing of habitat: nearly every disperser eventually settles somewhere. So contrast lives at distances comparable to habitat spacing.

**Settling at home** (`check_home.R`, example landscape, distance 10, settle_distance 2):

| | Habitat median P | Matrix median P | Spearman ρ with "anywhere" |
|---|---|---|---|
| Settle anywhere | 0.93 | 0.35 | — |
| Settle beyond a 2-cell site | 0.80 | 0.33 | habitat 0.89, matrix 0.99 |

- Excluding home matters inside habitat. Small isolated patches show low values at their centres, because dispersers must leave them to settle.
- It costs one exact solve per cell: 26 s for 2,500 cells. That isn't viable at scale.
- A possible route: P_away(i) needs only the block of the Green's function among the site's cells (Woodbury, a rank-|site| update). That could come from selected inversion or from estimation, but it's unexplored.

**Settlement rule.** First-contact settlement (habitat absorbs on arrival) is the small-`settle_distance` limit of the rate model: Spearman ρ 1.000 at 0.5 cells. So it needs no separate rule.

**Gross flow** (`check_gross.R`). Σᵢ wᵢ (current from a unit source at i)², estimated by random-sign monopoles (signs ±1 at the sources, draining to the grounds):
- unbiased, with error falling as 1/√n;
- 16 draws: median |error| 12%; 64 draws: 5% (ρ 0.999); 256 draws: 2.6%.

**Maps** (`compare_maps.R`, `prototype/compare_maps.png`):
- Settlement P against `dp_isolation()`'s −log resistance: ρ 0.79 anywhere, 0.82 away from home (0.64 within habitat). They are related but different. P is more local and habitat-driven; `dp_isolation()` is smoother.
- The gross-flow map mostly shows where dispersers *are*: concentrated around sources, spanning about 13 orders of magnitude, and less corridor-like than `dp_omni()` (ρ 0.88).
- The omni net-flow map shows rings at patch edges, because opposing flows cancel inside patches. It's probably not useful in omni mode.
- The flux mode (origin → destination) isn't prototyped yet.

## 6. API: one layout, not settled

Package prefixes name method families (`cs_`, `os_`, `dp_`). The settlement methods are a different model, using grounds and a dispersal distance rather than pairs within a radius, and none of them use dipoles. Only the gross-flow map uses random superposition, with monopoles. One idea is a parallel family, with `ds_` as a placeholder prefix:

| Question | Radius family (dipoles) | Settlement family (grounds) |
|---|---|---|
| Where does movement pass? | `dp_omni()` | `ds_omni()`: gross flow (monopoles) |
| Net flow from one distribution to another | `dp_flux()` | `ds_flux()`: one solve |
| How connected is each place? | `dp_isolation()` | `ds_settlement()`: P(settle); with a destination, P(reach it) and settlers arriving |
| Between focal nodes | `dp_pairwise()` | probably none |

**Alternatives to weigh:**
- `dispersal_distance` as an alternative to `radius` within the existing functions.
- Only a per-cell function, plus a vignette recipe for the flow maps with `cs_advanced()`.
- Organizing everything by question rather than by method.

**Shared engine.** The grounds are extra terms on the diagonal (where the 1e-12 floor sits today), and the factorization, solves, per-link sums and random signs carry over.

**`dp_isolation()` under any layout.** An earlier version of this note proposed slimming it to its resistance layers. Instead (2026-11-24), `coverage` and `effective_coverage` were replaced by two absolute layers, `target_area` (Σ t a over the targets in reach, exact) and `accessible_area` (target_area × R\*/R, against continuous habitat at the same radius). They meet goals 1, 2, 4 (with `site_radius` in km), 5 and 6 with a single reach parameter, which suits TreeShift. They fail goal 3 at some cells: accessible area can still fall with radius (8% of core cells, 20 → 40 km), from the fixed-proportion withdrawal. The settlement model stays a candidate for demographic, SAMC-style analyses, where its second parameter is natural. The function was then renamed `dp_accessibility()`, with `accessible_area` as its headline layer, conductance in place of resistance, `mean_resistance` dropped and `site_radius` always in pixels.

## 7. Open questions

1. **Settling at home.** Include it (exact, one solve; rewards large patches, like PC/ECA), exclude it (more informative within habitat, but needs a scalable method), or offer both?
2. **Saturation.** P approaches 1 at long distances. Should there be an additional readout, such as mean distance or time to settlement (also one solve), or the share settling beyond a distance?
3. **Flow maps.** Is the gross-flow map worth having, given that it mostly shows source neighbourhoods? Would a normalized version (against the uniform circuit, like flow potential) bring out corridors? Is net flow useful outside flux mode?
4. **Parameter count.** The model has two real parameters, `distance` and `settle_distance`, plus two unit conventions: the reference resistance for `distance`, and quality 1 for `settle_distance`.
   - **Why both are needed:** with the landscape fixed, P depends on both distances relative to the landscape's scale, separately.
   - **One parameter only in the first-contact limit,** which makes habitat binary and scores every habitat cell 1 if settling at home counts.
   - **Per-visit settlement probabilities** keep graded quality, but they depend on resolution.
   - **Defaults are awkward:** a fraction of `distance` breaks monotonicity across distances; a number of cells breaks resolution invariance; first contact loses quality.
   - **The cost:** this makes the model less attractive for simple tools like TreeShift, where one reach parameter is the norm. It may suit demographic (SAMC-style) analyses better than a default connectivity map.
5. **Mortality.** Uniform per area, or an optional mortality surface (as SAMC allows)?
6. **Flux mode:** prototype colonization probability and arrival pressure for a shifting range.
7. **Novelty and positioning** against `samc` and `cs_advanced()`. Our additions would be the km parameterization that holds across resolutions, terra integration, reusable factorizations, the cross-era framing and the monopole gross-flow map.
