# Dipole methods: many balanced injections solved against one factored
# circuit and combined by superposition. Loaded into Main by circuitscaper's
# R code; depends only on Julia's standard libraries. See dev/dipole/SPEC.md.
module CircuitscaperDipole

using SparseArrays, LinearAlgebra, Random
using Base.Threads: @threads

# Identifies this Julia process, so R can tell whether a circuit it holds
# was built in the Julia that is running now
const SESSION = string(rand(RandomDevice(), UInt64); base = 16)

# Per-node conductance to ground. Its only job is to make the matrix
# positive definite: at 1e-8 it drained measurable current from
# low-conductance cells; 1e-12 matches Circuitscape.
const GROUND_FLOOR = 1e-12

# Progress: `progress` is `nothing` or a callback from R, called as
# progress(message, amount) on the main task only (never inside @threads):
# amount 0 announces a step, amount > 0 completes it. It only reports, so
# results don't depend on it.
tick(progress::Nothing, message::AbstractString, amount::Real) = nothing
function tick(progress, message::AbstractString, amount::Real)
    progress(String(message), Float64(amount))
    nothing
end

# "draws 1-32 of 64": the draws (or pairs) of one batch
span(r::AbstractRange, n::Integer) = string(first(r), "-", last(r), " of ", n)


# Graph ------------------------------------------------------------------------

# Topology of the raster circuit: nodes are the valid cells, numbered down
# the columns of the nr x nc (top row first) matrix; links are 8-neighbour.
struct Graph
    nr::Int
    nc::Int
    id::Matrix{Int}          # node number of each cell, 0 for invalid cells
    node_r::Vector{Int}
    node_c::Vector{Int}
    a::Vector{Int}           # link endpoints
    b::Vector{Int}
    diagonal::BitVector
    comp::Vector{Int}        # connected component of each node
    ncomp::Int
end

nnodes(gr::Graph) = length(gr.node_r)
nlinks(gr::Graph) = length(gr.a)

function Graph(valid::AbstractMatrix{Bool})
    nr, nc = size(valid)
    id = zeros(Int, nr, nc)
    node_r = Int[]
    node_c = Int[]
    k = 0
    for c in 1:nc, r in 1:nr
        if valid[r, c]
            k += 1
            id[r, c] = k
            push!(node_r, r)
            push!(node_c, c)
        end
    end
    # Same link order as the prototype: by direction, then down the columns
    a = Int[]
    b = Int[]
    diagonal = Bool[]
    for (dr, dc) in ((0, 1), (1, 0), (1, 1), (1, -1))
        for c in max(1, 1 - dc):min(nc, nc - dc), r in 1:(nr - dr)
            u = id[r, c]
            v = id[r + dr, c + dc]
            if u > 0 && v > 0
                push!(a, u)
                push!(b, v)
                push!(diagonal, dr != 0 && dc != 0)
            end
        end
    end
    comp, ncomp = components(k, a, b)
    Graph(nr, nc, id, node_r, node_c, a, b, BitVector(diagonal), comp, ncomp)
end

# Connected components by union-find, labelled in order of first node
function components(n::Int, a::Vector{Int}, b::Vector{Int})
    parent = collect(1:n)
    function root(x)
        while parent[x] != x
            parent[x] = parent[parent[x]]
            x = parent[x]
        end
        x
    end
    for e in eachindex(a)
        ra = root(a[e])
        rb = root(b[e])
        ra != rb && (parent[max(ra, rb)] = min(ra, rb))
    end
    comp = zeros(Int, n)
    label = zeros(Int, n)
    m = 0
    for i in 1:n
        r = root(i)
        if label[r] == 0
            m += 1
            label[r] = m
        end
        comp[i] = label[r]
    end
    comp, m
end


# Circuit ----------------------------------------------------------------------

# A graph with link conductances and the Cholesky factor of its Laplacian
# plus the ground floor
struct Circuit
    graph::Graph
    g::Vector{Float64}
    fac::SparseArrays.CHOLMOD.Factor{Float64}
end

# Circuitscape's averaged conductances: (c_u + c_v) / 2, diagonals / sqrt(2)
function link_conductances(gr::Graph, cond::AbstractMatrix{<:Real})
    g = Vector{Float64}(undef, nlinks(gr))
    for e in eachindex(g)
        i = gr.a[e]
        j = gr.b[e]
        x = (cond[gr.node_r[i], gr.node_c[i]] + cond[gr.node_r[j], gr.node_c[j]]) / 2
        g[e] = gr.diagonal[e] ? x / sqrt(2) : x
    end
    g
end

function laplacian(gr::Graph, g::Vector{Float64}; floor::Float64 = GROUND_FLOOR)
    n = nnodes(gr)
    d = zeros(n)
    for e in eachindex(g)
        d[gr.a[e]] += g[e]
        d[gr.b[e]] += g[e]
    end
    d .+= floor
    sparse(vcat(gr.a, gr.b, 1:n), vcat(gr.b, gr.a, 1:n), vcat(-g, -g, d), n, n)
end

function Circuit(gr::Graph, cond::AbstractMatrix{<:Real})
    g = link_conductances(gr, cond)
    fac = cholesky(Symmetric(laplacian(gr, g)))
    Circuit(gr, g, fac)
end

# Uniform circuit for flow potential: conductance 1 on the same cells
uniform_circuit(gr::Graph) = Circuit(gr, ones(gr.nr, gr.nc))


# Accumulation -----------------------------------------------------------------

# Running sums over draws of a per-link quantity f(I_e), split by draw
# parity: column 1 holds odd draws, column 2 even draws
struct LinkSums
    s::Matrix{Float64}
    n::Vector{Int}
end
LinkSums(nl::Int) = LinkSums(zeros(nl, 2), [0, 0])

parity(draw::Integer) = isodd(draw) ? 1 : 2

# Solve the columns of B (draws first_draw, first_draw + 1, ...) and add
# f of each link current to the sums. Each link's sum runs over the draws in
# order, so results don't depend on the number of threads.
function accumulate!(acc::LinkSums, circ::Circuit, B::Matrix{Float64}, first_draw::Int;
                     f::F = abs2) where {F}
    k = size(B, 2)
    Vt = permutedims(circ.fac \ B)     # draws x nodes: a node's values are contiguous
    par = [parity(first_draw + j - 1) for j in 1:k]
    a, b, g, s = circ.graph.a, circ.graph.b, circ.g, acc.s
    @threads for e in eachindex(a)
        ia = a[e]
        ib = b[e]
        ge = g[e]
        s1 = 0.0
        s2 = 0.0
        @inbounds for j in 1:k
            x = f(ge * (Vt[j, ia] - Vt[j, ib]))
            if par[j] == 1
                s1 += x
            else
                s2 += x
            end
        end
        s[e, 1] += s1
        s[e, 2] += s2
    end
    for p in par
        acc.n[p] += 1
    end
    acc
end

# Per-node sums over incident links, of each column of x (links x k)
function node_sums(gr::Graph, x::AbstractMatrix{Float64})
    out = zeros(nnodes(gr), size(x, 2))
    for p in axes(x, 2), e in axes(x, 1)
        out[gr.a[e], p] += x[e, p]
        out[gr.b[e], p] += x[e, p]
    end
    out
end

# Per-node sums over incident links of squared current times the link's
# resistance, 1 / g: the power dissipated, from per-link sums of squared
# current x (links x k)
power_sums(c::Circuit, x::AbstractMatrix{Float64}) = node_sums(c.graph, x ./ c.g)

# Columns per solve. Each column costs a few n-vectors (~0.4 GB at 18M
# nodes), small next to the factor (~14 GB there), while narrow batches
# leave the multithreaded solve underused: at 18M nodes, 16 columns solved
# 32 draws in 85 s against 238 s with 3, for 3 GiB more peak memory.
default_batch(n::Int) = clamp(300_000_000 ÷ max(n, 1), 8, 32)

# Accumulate the given injections (nodes x draws), `batch` columns at a time
function accumulate_given(circ::Circuit, B::AbstractMatrix{<:Real}; batch::Int = 8, f = abs2)
    acc = LinkSums(nlinks(circ.graph))
    for s0 in 1:batch:size(B, 2)
        cols = s0:min(size(B, 2), s0 + batch - 1)
        accumulate!(acc, circ, Matrix{Float64}(B[:, cols]), s0; f = f)
    end
    acc
end


# Kernel -----------------------------------------------------------------------

# A set of cell offsets (dr, dc) around a source cell. For each row offset
# dr = dr0 + d - 1 the column offsets are one run, -hw[d, kr] .. hw[d, kr]
# (none if hw < 0). The kernel may vary by the source cell's grid row:
# kr = rowmap[row].
struct Kernel
    dr0::Int
    hw::Matrix{Int}          # row offsets x kernel rows
    rowmap::Vector{Int}      # grid row -> kernel row
end

Kernel(dr0::Integer, hw::AbstractMatrix{<:Real}, rowmap::AbstractVector{<:Real}) =
    Kernel(Int(dr0), Matrix{Int}(round.(Int, hw)), Vector{Int}(round.(Int, rowmap)))

# A disk of `radius` pixels: dr^2 + dc^2 <= radius^2
function pixel_kernel(radius::Real, nr::Int)
    R = floor(Int, radius)
    hw = [isqrt_floor(radius^2 - dr^2) for dr in -R:R]
    Kernel(-R, reshape(hw, :, 1), ones(Int, nr))
end

# Largest h with h^2 <= x, without trusting sqrt's rounding
function isqrt_floor(x::Real)
    x < 0 && return -1
    h = floor(Int, sqrt(x))
    while (h + 1)^2 <= x
        h += 1
    end
    while h^2 > x
        h -= 1
    end
    h
end


# Window sums ------------------------------------------------------------------

# Node numbers in each component
function component_members(gr::Graph)
    members = [Int[] for _ in 1:gr.ncomp]
    for i in eachindex(gr.comp)
        push!(members[gr.comp[i]], i)
    end
    members
end

# Per-row prefix sums of w over one component's bounding box, for summing w
# over a kernel window: P[k + 1, r] is the sum of w over columns c0 .. c0 + k - 1
# of row r0 + r - 1
struct WindowSums
    P::Matrix{Float64}
    r0::Int
    r1::Int
    c0::Int
    c1::Int
end

function WindowSums(gr::Graph, w::Vector{Float64}, nodes::Vector{Int})
    r0, r1 = extrema(gr.node_r[i] for i in nodes)
    c0, c1 = extrema(gr.node_c[i] for i in nodes)
    P = zeros(c1 - c0 + 2, r1 - r0 + 1)
    for j in nodes
        P[gr.node_c[j] - c0 + 2, gr.node_r[j] - r0 + 1] = w[j]
    end
    cumsum!(P, P, dims = 1)
    WindowSums(P, r0, r1, c0, c1)
end

# Sum of w over node i's kernel (its own cell included), within the component
function window_sum(ws::WindowSums, K::Kernel, gr::Graph, i::Int)
    ri = gr.node_r[i]
    ci = gr.node_c[i]
    kr = K.rowmap[ri]
    acc = 0.0
    for d in axes(K.hw, 1)
        h = K.hw[d, kr]
        h < 0 && continue
        r = ri + K.dr0 + d - 1
        ws.r0 <= r <= ws.r1 || continue
        lo = max(ci - h, ws.c0)
        hi = min(ci + h, ws.c1)
        lo > hi && continue
        acc += ws.P[hi - ws.c0 + 2, r - ws.r0 + 1] - ws.P[lo - ws.c0 + 1, r - ws.r0 + 1]
    end
    acc
end

# Sampling ---------------------------------------------------------------------

# Dipole endpoints (i, j) drawn exactly with probability proportional to
# w1_i * w2_j * k_ij over ordered pairs with i != j in the same component, in
# two stages and without rejection. i is drawn in proportion to
# w1_i * (Kw2_i - w2_i), its share of the pair weight. Then j is drawn in
# proportion to w2_j among the cells in i's kernel (or, with no kernel, i's
# component), i itself left out: with a kernel, a kernel row by its sum of
# w2, from per-row prefix sums, then a column by binary search. Each dipole
# costs O(kernel rows), however w2 is spread.
struct Sampler
    graph::Graph
    w1::Vector{Float64}
    w2::Vector{Float64}
    kernel::Union{Nothing, Kernel}
    src::Vector{Int}                            # nodes i with q_i > 0
    cum1::Vector{Float64}                       # cumulative q over src
    ws::Vector{Union{Nothing, WindowSums}}      # kernel: per component, of w2
    dst::Vector{Vector{Int}}                    # no kernel: per component, w2 > 0
    cum2::Vector{Vector{Float64}}               # no kernel: cumulative w2 over dst
    pos2::Vector{Int}                           # no kernel: node -> index in dst
end

function Sampler(gr::Graph, w1::AbstractVector{<:Real}, w2::AbstractVector{<:Real},
                 kernel::Union{Nothing, Kernel})
    w1 = Vector{Float64}(w1)
    w2 = Vector{Float64}(w2)
    n = nnodes(gr)
    members = component_members(gr)
    q = zeros(n)
    ws = Vector{Union{Nothing, WindowSums}}(nothing, gr.ncomp)
    dst = [Int[] for _ in 1:gr.ncomp]
    cum2 = [Float64[] for _ in 1:gr.ncomp]
    pos2 = zeros(Int, n)
    # Each i's weight of other cells in reach; tiny residues of rounding in
    # the prefix sums count as none
    others(total, i) = (t = total - w2[i]; t > 1e-12 * total ? t : 0.0)
    for (c, nodes) in enumerate(members)
        any(i -> w1[i] > 0, nodes) && any(i -> w2[i] > 0, nodes) || continue
        if kernel === nothing
            dst[c] = filter(i -> w2[i] > 0, nodes)
            cum2[c] = cumsum(w2[dst[c]])
            for (k, i) in enumerate(dst[c])
                pos2[i] = k
            end
            tot = cum2[c][end]
            for i in nodes
                w1[i] > 0 && (q[i] = w1[i] * others(tot, i))
            end
        else
            ws[c] = WindowSums(gr, w2, nodes)
            wc = ws[c]
            @threads for i in nodes
                w1[i] > 0 && (q[i] = w1[i] * others(window_sum(wc, kernel, gr, i), i))
            end
        end
    end
    src = findall(>(0), q)
    Sampler(gr, w1, w2, kernel, src, cumsum(q[src]), ws, dst, cum2, pos2)
end

pick(rng, nodes, cum) = nodes[min(searchsortedfirst(cum, rand(rng) * cum[end]), length(nodes))]

# Stage 2: j in proportion to w2 among the cells in i's kernel, without i.
# Returns 0 if rounding leaves nothing to draw (the caller draws again).
function draw_destination(rng::AbstractRNG, s::Sampler, i::Int)
    gr = s.graph
    if s.kernel === nothing
        c = gr.comp[i]
        cum = s.cum2[c]
        isempty(cum) && return 0
        wi = s.pos2[i] > 0 ? s.w2[i] : 0.0
        u = rand(rng) * (cum[end] - wi)
        if s.pos2[i] > 0
            before = s.pos2[i] > 1 ? cum[s.pos2[i] - 1] : 0.0
            u >= before && (u += wi)
        end
        k = min(searchsortedlast(cum, u) + 1, length(cum))
        return s.dst[c][k]
    end
    ws = s.ws[gr.comp[i]]
    ws === nothing && return 0
    K = s.kernel
    ri = gr.node_r[i]
    ci = gr.node_c[i]
    kr = K.rowmap[ri]
    P = ws.P
    total = 0.0
    for d in axes(K.hw, 1)
        h = K.hw[d, kr]
        h < 0 && continue
        r = ri + K.dr0 + d - 1
        ws.r0 <= r <= ws.r1 || continue
        lo = max(ci - h, ws.c0)
        hi = min(ci + h, ws.c1)
        lo > hi && continue
        total += P[hi - ws.c0 + 2, r - ws.r0 + 1] - P[lo - ws.c0 + 1, r - ws.r0 + 1]
    end
    u = rand(rng) * (total - s.w2[i])
    for d in axes(K.hw, 1)
        h = K.hw[d, kr]
        h < 0 && continue
        r = ri + K.dr0 + d - 1
        ws.r0 <= r <= ws.r1 || continue
        lo = max(ci - h, ws.c0)
        hi = min(ci + h, ws.c1)
        lo > hi && continue
        rr = r - ws.r0 + 1
        base = P[lo - ws.c0 + 1, rr]
        rs = P[hi - ws.c0 + 2, rr] - base
        own = r == ri
        own && (rs -= s.w2[i])
        if u < rs
            t = base + u
            # Skip i's own cell: past it, shift the target by its weight
            own && t >= P[ci - ws.c0 + 1, rr] && (t += s.w2[i])
            v = view(P, (lo - ws.c0 + 2):(hi - ws.c0 + 2), rr)
            col = min(lo + searchsortedlast(v, t), hi)
            return gr.id[r, col]
        end
        u -= rs
    end
    0
end

function draw_pair(rng::AbstractRNG, s::Sampler)
    while true
        i = pick(rng, s.src, s.cum1)
        j = draw_destination(rng, s, i)
        (j == 0 || j == i || s.w2[j] <= 0 || s.graph.comp[j] != s.graph.comp[i]) && continue
        return i, j
    end
end

# Each draw is its own random stream, seeded by (seed, draw), so a draw's
# injection doesn't depend on batching or threads
draw_rng(seed::Integer, draw::Integer) = Xoshiro(UInt64[seed, draw])

random_sign(rng::AbstractRNG) = rand(rng, Bool) ? 1.0 : -1.0

# Fill B's columns with draws `draws`: m dipoles each, weighted by
# `weight(rng)` (random signs; another distribution, e.g. Cauchy for
# absolute current, plugs in here). With `center` (the mean dipole, a node
# vector), each dipole is centered: a draw's column is
# sum_d s_d (dipole_d - center), so its squared current estimates the
# dipoles' variance instead of their mean square.
function injections!(B::Matrix{Float64}, s::Sampler, seed::Integer, draws::AbstractVector{<:Integer},
                     m::Integer; weight::W = random_sign,
                     center::Union{Nothing, Vector{Float64}} = nothing) where {W}
    fill!(B, 0.0)
    @threads for k in eachindex(draws)
        rng = draw_rng(seed, draws[k])
        tot = 0.0
        for _ in 1:m
            i, j = draw_pair(rng, s)
            sg = weight(rng)
            tot += sg
            @inbounds B[i, k] += sg
            @inbounds B[j, k] -= sg
        end
        if center !== nothing
            @inbounds for i in eachindex(center)
                B[i, k] -= tot * center[i]
            end
        end
    end
    B
end

# S: the sum of w1_i * w2_j * k_ij over exactly the ordered pairs the
# sampler can produce (i != j, same component)
function pair_sum(s::Sampler)
    gr = s.graph
    self = sum(s.w1[i] * s.w2[i] for i in eachindex(s.w1); init = 0.0)
    total = 0.0
    if s.kernel === nothing
        W1 = zeros(gr.ncomp)
        W2 = zeros(gr.ncomp)
        for i in eachindex(s.w1)
            W1[gr.comp[i]] += s.w1[i]
            W2[gr.comp[i]] += s.w2[i]
        end
        total = sum(W1 .* W2)
    else
        for nodes in component_members(gr)
            total += kernel_pair_sum(s, nodes)
        end
    end
    max(total - self, 0.0)
end

# One component's sum over i of w1_i * (sum of w2 over i's kernel)
function kernel_pair_sum(s::Sampler, nodes::Vector{Int})
    gr = s.graph
    any(i -> s.w1[i] > 0, nodes) && any(i -> s.w2[i] > 0, nodes) || return 0.0
    ws = WindowSums(gr, s.w2, nodes)
    # Fixed chunks summed in order, so S doesn't depend on the thread count
    chunks = collect(Iterators.partition(nodes, 4096))
    part = zeros(length(chunks))
    @threads for k in eachindex(chunks)
        t = 0.0
        for i in chunks[k]
            s.w1[i] > 0 || continue
            t += s.w1[i] * window_sum(ws, s.kernel, gr, i)
        end
        part[k] = t
    end
    sum(part)
end

# Per node i, the sum of w over i's kernel (its own cell included) within its
# component; with no kernel, the component's total of w
function kernel_sums(gr::Graph, w::Vector{Float64}, K::Union{Nothing, Kernel})
    out = zeros(nnodes(gr))
    if K === nothing
        tot = zeros(gr.ncomp)
        for i in eachindex(w)
            tot[gr.comp[i]] += w[i]
        end
        for i in eachindex(out)
            out[i] = tot[gr.comp[i]]
        end
        return out
    end
    for nodes in component_members(gr)
        any(i -> w[i] > 0, nodes) || continue
        ws = WindowSums(gr, w, nodes)
        @threads for i in nodes
            out[i] = window_sum(ws, K, gr, i)
        end
    end
    out
end

# Random-sign dipoles from `s`, solved against each circuit. Returns one
# LinkSums per circuit; all circuits see the same injections.
#
# With `progress`, each batch is 1 + length(circs) steps: sampling its
# injections, then solving them against each circuit.
function run_dipoles(circs::Vector{Circuit}, s::Sampler, seed::Integer, n_draws::Integer,
                     m::Integer; batch::Int = default_batch(nnodes(s.graph)), f = abs2,
                     weight = random_sign, center = nothing, progress = nothing)
    n = nnodes(s.graph)
    accs = [LinkSums(nlinks(c.graph)) for c in circs]
    for s0 in 1:batch:n_draws
        draws = s0:min(n_draws, s0 + batch - 1)
        tick(progress, "Sampling dipoles: draws " * span(draws, n_draws), 0)
        B = injections!(Matrix{Float64}(undef, n, length(draws)), s, seed, draws, m;
                        weight = weight, center = center)
        tick(progress, "", 1)
        for (k, (c, acc)) in enumerate(zip(circs, accs))
            tick(progress, solve_message(k, length(circs), "draws " * span(draws, n_draws)), 0)
            accumulate!(acc, c, B, s0; f = f)
            tick(progress, "", 1)
        end
    end
    accs
end

# Callers pass a circuit, then optionally its uniform twin
solve_message(k::Integer, n::Integer, what::AbstractString) =
    string("Solving ", k == 2 ? "flow potential" : "current", ": ", what)


# Focal nodes ------------------------------------------------------------------

# Groups of focal nodes by connected component; pairs never span components
function focal_groups(gr::Graph, nodes::Vector{Int})
    groups = Dict{Int, Vector{Int}}()
    for v in nodes
        push!(get!(groups, gr.comp[v], Int[]), v)
    end
    [groups[k] for k in sort!(collect(keys(groups))) if length(groups[k]) >= 2]
end

# Each draw weights every pair of focal nodes (within a component) by an
# independent standard normal: b_i = sum_{j>i} xi_ij - sum_{j<i} xi_ji, so
# the injection is antisymmetric in pairs and sums to zero. The mean squared
# link current over draws estimates sum_{i<j} I_e(i, j)^2.
function focal_injections!(B::Matrix{Float64}, groups::Vector{Vector{Int}}, seed::Integer,
                           draws::AbstractVector{<:Integer})
    fill!(B, 0.0)
    @threads for k in eachindex(draws)
        rng = draw_rng(seed, draws[k])
        for nodes in groups, i in eachindex(nodes), j in (i + 1):length(nodes)
            xi = randn(rng)
            @inbounds B[nodes[i], k] += xi
            @inbounds B[nodes[j], k] -= xi
        end
    end
    B
end

# Solved against each of the circuits `ids` (all on the same graph, e.g. a
# circuit and its uniform twin), with the same injections. Returns per
# circuit the per-node sums of squared current and of power (nodes x 2: odd
# draws, even draws).
function pairwise_random(ids, nodes, seed::Real, n_draws::Real, batch::Real,
                         progress = nothing)
    circs = [circuit(id) for id in asvec(ids)]
    gr = first(circs).graph
    groups = focal_groups(gr, Vector{Int}(round.(Int, asvec(nodes))))
    isempty(groups) && return (n_pairs = 0, cells = Matrix{Float64}[], power = Matrix{Float64}[])
    b = batch > 0 ? Int(batch) : default_batch(nnodes(gr))
    accs = [LinkSums(nlinks(gr)) for _ in circs]
    for s0 in 1:b:Int(n_draws)
        draws = s0:min(Int(n_draws), s0 + b - 1)
        tick(progress, "Sampling pair weights: draws " * span(draws, Int(n_draws)), 0)
        B = focal_injections!(Matrix{Float64}(undef, nnodes(gr), length(draws)), groups,
                              Int(seed), draws)
        tick(progress, "", 1)
        for (k, (c, acc)) in enumerate(zip(circs, accs))
            tick(progress, solve_message(k, length(circs), "draws " * span(draws, Int(n_draws))), 0)
            accumulate!(acc, c, B, s0)
            tick(progress, "", 1)
        end
    end
    (n_pairs = sum(length(g) * (length(g) - 1) ÷ 2 for g in groups),
     cells = [node_sums(gr, acc.s) for acc in accs],
     power = [power_sums(c, acc.s) for (c, acc) in zip(circs, accs)])
end

# Exact sum over pairs of focal nodes of squared link current, from one
# solve per node: with y_i a link's current for unit flow from node i to its
# component's first node, sum_{i<j} (y_i - y_j)^2 = N sum y_i^2 - (sum y_i)^2.
# Returns per-node sums over incident links (nodes x 1), of squared current
# and of power. With `progress`, the whole solve is one step, in fractions
# per batch; `uniform` only labels it.
function pairwise_exact(id::Real, nodes, batch::Real, progress = nothing,
                        uniform::Bool = false)
    c = circuit(id)
    gr = c.graph
    groups = focal_groups(gr, Vector{Int}(round.(Int, asvec(nodes))))
    isempty(groups) && return (n_pairs = 0, cells = zeros(0, 1), power = zeros(0, 1))
    jobs = [(v, g[1]) for g in groups for v in g[2:end]]
    n_comp = zeros(Int, gr.ncomp)
    for g in groups
        n_comp[gr.comp[g[1]]] = length(g)
    end
    b = batch > 0 ? Int(batch) : default_batch(nnodes(gr))
    a, bb, g = gr.a, gr.b, c.g
    sy = zeros(nlinks(gr))
    sy2 = zeros(nlinks(gr))
    nb = cld(length(jobs), b)
    for s0 in 1:b:length(jobs)
        span_jobs = s0:min(length(jobs), s0 + b - 1)
        tick(progress, solve_message(uniform ? 2 : 1, 2,
                                     "solves " * span(span_jobs, length(jobs))), 0)
        part = jobs[span_jobs]
        B = zeros(nnodes(gr), length(part))
        for (k, (v, ref)) in enumerate(part)
            B[v, k] = 1.0
            B[ref, k] = -1.0
        end
        Vt = permutedims(c.fac \ B)
        @threads for e in eachindex(a)
            t1 = 0.0
            t2 = 0.0
            @inbounds for k in axes(Vt, 1)
                y = g[e] * (Vt[k, a[e]] - Vt[k, bb[e]])
                t1 += y
                t2 += y * y
            end
            sy[e] += t1
            sy2[e] += t2
        end
        tick(progress, "", 1 / nb)
    end
    x = [max(n_comp[gr.comp[a[e]]] * sy2[e] - sy[e]^2, 0.0) for e in eachindex(a)]
    (n_pairs = sum(length(g) * (length(g) - 1) ÷ 2 for g in groups),
     cells = node_sums(gr, reshape(x, :, 1)), power = power_sums(c, reshape(x, :, 1)))
end


# Net flux ---------------------------------------------------------------------

# The injection whose single solve gives the signed sum over origin-destination
# pairs within reach, sum_ij o_i d_j k_ij I(i, j), per unit of pair weight:
#   b_i = (o_i (K d)_i - d_i (K o)_i) / W,   W = sum_i o_i (K d)_i,
# with K the kernel within each component, each cell's own pair included (it
# moves nothing). With no kernel and one component this is o/sum(o) - d/sum(d).
# K is symmetric, so b sums to zero in each component; the withdrawals are
# rescaled to make that exact despite rounding at the kernel's edge.
# Coverage: `pair_weight_in_reach` is W over the pair weight with no limits,
# sum(o) * sum(d); `origin_in_reach` is the share of origin weight on cells
# with any destination weight in reach, (K d)_i > 0, and
# `destination_in_reach` the same for destinations. A window of zeros sums to
# exactly 0 (its prefix sums are equal), so "> 0" is exact.
function flux_injection(gr::Graph, o::Vector{Float64}, d::Vector{Float64},
                        K::Union{Nothing, Kernel})
    Kd = kernel_sums(gr, d, K)
    Ko = kernel_sums(gr, o, K)
    inj = o .* Kd
    wd = d .* Ko
    pos = zeros(gr.ncomp)
    neg = zeros(gr.ncomp)
    for i in eachindex(inj)
        pos[gr.comp[i]] += inj[i]
        neg[gr.comp[i]] += wd[i]
    end
    W = sum(pos)
    reached(w, Kw) = sum(w[i] for i in eachindex(w) if Kw[i] > 0; init = 0.0) / sum(w)
    cover = (pair_weight_in_reach = W / (sum(o) * sum(d)),
             origin_in_reach = reached(o, Kd), destination_in_reach = reached(d, Ko))
    W > 0 || return (b = zeros(nnodes(gr)), W = 0.0, cover...)
    b = [(inj[i] - (neg[gr.comp[i]] > 0 ? wd[i] * pos[gr.comp[i]] / neg[gr.comp[i]] : 0.0)) / W
         for i in eachindex(inj)]
    (b = b, W = W, cover...)
end

flux_injection(id::Real, o, d, dr0, hw, rowmap) =
    flux_injection(circuit(id).graph, Vector{Float64}(asvec(o)), Vector{Float64}(asvec(d)),
                   make_kernel(dr0, hw, rowmap))

# One solve of a given injection (balanced within each component). Returns
# per-node sums over incident links of |I|, I^2, the x and y components of I
# times the link's unit direction (x east, y north on the grid), and the
# power I^2 / g.
function flux(id::Real, b)
    c = circuit(id)
    gr = c.graph
    V = c.fac \ Vector{Float64}(asvec(b))
    out = zeros(nnodes(gr), 5)
    for e in eachindex(gr.a)
        i = gr.a[e]
        j = gr.b[e]
        I = c.g[e] * (V[i] - V[j])
        dx = gr.node_c[j] - gr.node_c[i]
        dy = gr.node_r[i] - gr.node_r[j]
        len = sqrt(dx^2 + dy^2)
        for v in (i, j)
            out[v, 1] += abs(I)
            out[v, 2] += I^2
            out[v, 3] += I * dx / len
            out[v, 4] += I * dy / len
            out[v, 5] += I^2 / c.g[e]
        end
    end
    out
end

# Isolation --------------------------------------------------------------------

# Per-cell effective resistance to target cells, from random-sign dipoles
# across every link. Draw r injects b = sum_e s_e sqrt(g_e) (e_a - e_b), with
# independent signs s_e = ±1. Since sum_e g_e (e_a - e_b)(e_a - e_b)' = L, the
# solution y = L^-1 b has E[(y_i - y_j)^2] = R_ij, and for weights q summing
# to 1 on i's component, E[(y_i - q'y)^2] = (e_i - q)' L^+ (e_i - q).
#
# With target weights t, i's targets are the other cells of its component
# within its kernel, weighted q_j = t_j / A_i, A_i = sum_{j != i} t_j.
#
# Each cell stands for a site: the mean of y over the valid cells of its
# component within the site kernel, ytilde = P y, P row-stochastic. This
# spreads the unit current over the site instead of one cell, which keeps a
# cell's own links (its contact resistance) from dominating. Everything
# below then applies to ytilde: R_ij becomes the resistance between sites i
# and j, (P_i - P_j) L^+ (P_i - P_j)'. With no site kernel, ytilde = y.
#
# Per draw, with m1 = q'ytilde and m2 = q'(ytilde.^2):
#   resistance to the target distribution:  (y_i - m1)^2
#   mean resistance to targets:  sum_j q_j (y_i - y_j)^2 = (y_i - m1)^2 + (m2 - m1^2)
# Each is an unbiased estimate; their mean over draws is the result.
#
# A link's signs depend only on (seed, draw), so a circuit and its uniform
# twin see the same signs (their ratio is then less noisy), and results don't
# depend on batching or the number of threads.
function link_injections!(B::Matrix{Float64}, c::Circuit, seed::Integer,
                          draws::AbstractVector{<:Integer})
    a, b, g = c.graph.a, c.graph.b, c.g
    fill!(B, 0.0)
    @threads for k in eachindex(draws)
        rng = draw_rng(seed, draws[k])
        @inbounds for e in eachindex(a)
            x = random_sign(rng) * sqrt(g[e])
            B[a[e], k] += x
            B[b[e], k] -= x
        end
    end
    B
end

# Sum of x over each node's kernel (its own cell included), within its
# component; with no kernel, over its whole component. Unlike kernel_sums,
# x may be negative.
function window_sums(gr::Graph, x::Vector{Float64}, K::Union{Nothing, Kernel},
                     members::Vector{Vector{Int}})
    out = zeros(nnodes(gr))
    if K === nothing
        tot = zeros(gr.ncomp)
        for i in eachindex(x)
            tot[gr.comp[i]] += x[i]
        end
        for i in eachindex(out)
            out[i] = tot[gr.comp[i]]
        end
        return out
    end
    for nodes in members
        any(i -> x[i] != 0, nodes) || continue
        ws = WindowSums(gr, x, nodes)
        @threads for i in nodes
            out[i] = window_sum(ws, K, gr, i)
        end
    end
    out
end

# Per-cell sums over draws for one statistic: columns sum x, sum x^2 on the
# circuit, then sum u, sum u^2 and sum x u with u the same statistic on the
# uniform twin (zero without one)
function isolation_stats!(dist::Matrix{Float64}, mean::Matrix{Float64},
                          ys::Vector{Vector{Float64}}, t::Vector{Float64}, A::Vector{Float64},
                          gr::Graph, K, members)
    vals = map(ys) do y
        s1 = window_sums(gr, t .* y, K, members) .- t .* y
        s2 = window_sums(gr, t .* y .^ 2, K, members) .- t .* y .^ 2
        d = zeros(length(y))
        m = zeros(length(y))
        for i in eachindex(y)
            A[i] > 0 || continue
            m1 = s1[i] / A[i]
            d[i] = (y[i] - m1)^2
            m[i] = d[i] + max(s2[i] / A[i] - m1^2, 0.0)
        end
        (d, m)
    end
    for (acc, k) in ((dist, 1), (mean, 2))
        x = vals[1][k]
        acc[:, 1] .+= x
        acc[:, 2] .+= x .^ 2
        if length(vals) > 1
            u = vals[2][k]
            acc[:, 3] .+= u
            acc[:, 4] .+= u .^ 2
            acc[:, 5] .+= x .* u
        end
    end
    nothing
end

# Isolation of every cell from each set of target weights (the columns of
# `targets`), on a circuit and optionally its uniform twin (`ids`). Returns
# per target set the reach A (summed target weight within reach) and, for
# each statistic, the per-cell sums over draws (nodes x 5; see
# isolation_stats!).
#
# With `progress`, each batch is 1 + length(circs) steps: solving the
# batch's link dipoles on each circuit, then summing over targets.
#
# The site kernel (sdr0, shw, srowmap) is empty for single cells. Also
# returns each cell's contact resistance, its own links in parallel,
# 1 / sum of their conductances, on the first circuit.
function isolation(ids, targets, dr0::Real, hw, rowmap, sdr0::Real, shw, srowmap,
                   seed::Real, n_draws::Real, batch::Real, progress = nothing)
    circs = [circuit(id) for id in asvec(ids)]
    gr = first(circs).graph
    n = nnodes(gr)
    T = reshape(Vector{Float64}(vec(targets)), n, :)
    K = make_kernel(dr0, hw, rowmap)
    S = make_kernel(sdr0, shw, srowmap)
    members = component_members(gr)
    site_size = S === nothing ? nothing : window_sums(gr, ones(n), S, members)
    site(y) = S === nothing ? y : window_sums(gr, y, S, members) ./ site_size
    gsum = zeros(n)
    for e in eachindex(gr.a)
        gsum[gr.a[e]] += first(circs).g[e]
        gsum[gr.b[e]] += first(circs).g[e]
    end
    ts = [T[:, k] for k in axes(T, 2)]
    reach = [window_sums(gr, t, K, members) .- t for t in ts]
    dist = [zeros(n, 5) for _ in ts]
    mean = [zeros(n, 5) for _ in ts]
    nd = Int(n_draws)
    b = batch > 0 ? Int(batch) : default_batch(n)
    for s0 in 1:b:nd
        draws = s0:min(nd, s0 + b - 1)
        what = "draws " * span(draws, nd)
        Ys = map(enumerate(circs)) do (k, c)
            tick(progress, string("Solving link dipoles", k == 2 ? " on the uniform circuit" : "",
                                  ": ", what), 0)
            B = link_injections!(Matrix{Float64}(undef, n, length(draws)), c, Int(seed), draws)
            Y = c.fac \ B
            tick(progress, "", 1)
            Y
        end
        tick(progress, "Summing over targets: " * what, 0)
        for j in eachindex(draws)
            ys = [site(Y[:, j]) for Y in Ys]
            for (k, t) in enumerate(ts)
                isolation_stats!(dist[k], mean[k], ys, t, reach[k], gr, K, members)
            end
        end
        tick(progress, "", 1)
    end
    (reach = reach, dist = dist, mean = mean, contact = 1 ./ gsum)
end

components(id::Real) = circuit(id).graph.comp


# Registry: circuits held for R ----------------------------------------------

# R holds integer handles; the circuits live here until R frees them
const CIRCUITS = Dict{Int, Circuit}()
const NEXT_ID = Ref(0)

function register!(c::Circuit)
    NEXT_ID[] += 1
    CIRCUITS[NEXT_ID[]] = c
    NEXT_ID[]
end

circuit(id::Real) = CIRCUITS[Int(id)]

function free!(ids)
    for id in ids
        delete!(CIRCUITS, Int(id))
    end
    nothing
end

# Build the circuit on the valid cells of `cond` (and its uniform twin).
# Returns handles and sizes.
# With `progress`, each factorization is a step.
function prepare(cond::AbstractMatrix{<:Real}, valid::AbstractMatrix{Bool}, uniform::Bool,
                 progress = nothing)
    gr = Graph(valid)
    nnodes(gr) > 0 || error("the conductance surface has no valid cells")
    tick(progress, "Factoring the circuit", 0)
    id = register!(Circuit(gr, cond))
    tick(progress, "", 1)
    uid = uniform ? prepare_uniform(id, progress) : 0
    (id = id, uniform_id = uid, n_nodes = nnodes(gr), n_links = nlinks(gr), n_components = gr.ncomp)
end

function prepare_uniform(id::Real, progress = nothing)
    tick(progress, "Factoring the uniform circuit (for flow potential)", 0)
    uid = register!(uniform_circuit(circuit(id).graph))
    tick(progress, "", 1)
    uid
end

# Kernel from R's description (see Kernel); an empty hw means no distance limit
make_kernel(dr0::Real, hw, rowmap) =
    isempty(hw) ? nothing : Kernel(Int(dr0), reshape(asvec(hw), size(hw, 1), :), asvec(rowmap))

# 'JuliaConnectoR' passes R vectors of length 1 as scalars
asvec(x::AbstractArray) = vec(x)
asvec(x::Real) = [x]

sampler(id::Real, w1, w2, dr0, hw, rowmap) =
    Sampler(circuit(id).graph, asvec(w1), asvec(w2), make_kernel(dr0, hw, rowmap))

# Random-sign dipoles drawn from (w1, w2, kernel), solved against the given
# circuits (all on the same graph). Returns S and, per circuit, the per-node
# sums of the per-link sums (nodes x 2: odd draws, even draws).
#
# With a non-empty `center_b` (an injection summing pair weights to `center_w`,
# e.g. flux_injection's b and W), dipoles are centered on their mean,
# center_w / S * center_b: the sums then estimate the variance of the pairs'
# currents, and R adds the mean's exact squared current back.
function random_dipoles(ids, w1, w2, dr0::Real, hw, rowmap, seed::Real, n_draws::Real,
                        n_dipoles::Real, batch::Real, center_b = Float64[], center_w::Real = 0.0,
                        progress = nothing)
    circs = [circuit(id) for id in asvec(ids)]
    s = sampler(first(asvec(ids)), w1, w2, dr0, hw, rowmap)
    S = pair_sum(s)
    # No pairs can be drawn; R reports it
    S > 0 || return (S = 0.0, cells = Matrix{Float64}[], power = Matrix{Float64}[])
    b = batch > 0 ? Int(batch) : default_batch(nnodes(s.graph))
    cb = Vector{Float64}(asvec(center_b))
    center = isempty(cb) ? nothing : (center_w / S) .* cb
    accs = run_dipoles(circs, s, Int(seed), Int(n_draws), Int(n_dipoles); batch = b,
                       center = center, progress = progress)
    (S = S, cells = [node_sums(c.graph, a.s) for (c, a) in zip(circs, accs)],
     power = [power_sums(c, a.s) for (c, a) in zip(circs, accs)])
end

# Columns per solve, as random_dipoles and pairwise_* choose them, for R to
# count progress steps
batch_size(n_nodes::Real, batch::Real) = batch > 0 ? Int(batch) : default_batch(Int(n_nodes))

# Parity hook: accumulate a given injection matrix (nodes x draws). Returns
# per-link sums (links x 2) and per-node sums (nodes x 2), columns odd and
# even draws.
function accumulate_injections(id::Real, B::AbstractMatrix{<:Real}, batch::Real)
    c = circuit(id)
    acc = accumulate_given(c, B; batch = Int(batch))
    (links = acc.s, cells = node_sums(c.graph, acc.s), n = acc.n)
end

# Pair sum S for (w1, w2, kernel), as random_dipoles computes it
pair_sum(id::Real, w1, w2, dr0, hw, rowmap) = pair_sum(sampler(id, w1, w2, dr0, hw, rowmap))

# The injection matrix random_dipoles would use, for tests
function injection_matrix(id::Real, w1, w2, dr0, hw, rowmap, seed::Real, n_draws::Real, n_dipoles::Real)
    s = sampler(id, w1, w2, dr0, hw, rowmap)
    injections!(Matrix{Float64}(undef, nnodes(s.graph), Int(n_draws)), s, Int(seed),
                1:Int(n_draws), Int(n_dipoles))
end

# n pairs (i, j) drawn by the sampler, one stream, for tests
function sample_pairs(id::Real, w1, w2, dr0, hw, rowmap, seed::Real, n::Real)
    s = sampler(id, w1, w2, dr0, hw, rowmap)
    rng = draw_rng(Int(seed), 1)
    out = Matrix{Int}(undef, Int(n), 2)
    for k in 1:Int(n)
        i, j = draw_pair(rng, s)
        out[k, 1] = i
        out[k, 2] = j
    end
    out
end

# Graph details, for tests
graph_info(id::Real) = (g = circuit(id).g, a = circuit(id).graph.a, b = circuit(id).graph.b,
                        comp = circuit(id).graph.comp)
end # module
