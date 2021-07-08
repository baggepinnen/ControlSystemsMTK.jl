using Base.Threads: @threads, nthreads, threadid
function coeff_cost_freq(Pd, Ps, freqs, vars) where F
    @info "Converting to Num"
    nums  = Num.(Ps)
    numsv = reduce(vcat, nums)
    @info "Extracting variables"
    found_vars = Symbolics.get_variables.(numsv)
    found_vars = unique(reduce(vcat, found_vars))
    si = findfirst(v->string(v) == "s", found_vars)
    si === nothing && error("Didn't find s symbol")
    s  = found_vars[si]
    svars = Set([vars; s])
    all(v ∈ svars for v in found_vars) || error("Found some variables that were not listed in vars. Found vars = $found_vars, expected vars: $svars")
    # all(any(isequal(v, v2) for v2 in [vars; s]) for v in found_vars) || error("Found some variables that were not listed in vars. Found vars = $found_vars")
    @info "Building functions"
    funs = [Symbolics.build_function(n, s, vars...; expression=Val(false))[1] for n in nums] # the first element in the tuple is out-of-place. If n is scalar, only a single function is returned.
    local cost
    logabs(x) = @fastmath log(abs(x))
    let Pd=Pd, funs=funs, freqs=freqs # closure bug trick
        function cost(x::AbstractArray{T}, _=nothing)::T where T
            any(<=(0), x) && (return T(Inf))
            c = [zero(T) for _ in 1:nthreads()]
            for (Pd, symfun) in zip(Pd, funs)
                for f in freqs # @threads
                    freq = complex(0, f)
                    data_val = evalfr(Pd, freq)
                    model_val = symfun(freq, x...)
                    c[threadid()] += sum(abs2.(
                        logabs.(data_val) .- logabs.(model_val)
                    ))
                end
            end
            sum(c)/(length(freqs) * length(Pd))
        end
    end
    cost, funs
end

"""
    fit_matching(Pd, Ps, freqs)

Given a set of systems estimated from data, `Pd`, and a set of symbolic systems `Ps`, find the numerical values of the symbolic parameters that make the two sets of systems agree as well as possible on the set of frequencies `freq`.
"""
function fit_matching(Pd, Ps, freqs, vars, x0; solver = ParticleSwarm(), lb, ub,
    opts = Optim.Options(
        store_trace       = true,
        show_trace        = true,
        show_every        = 100,
        iterations        = 10000,
        allow_f_increases = false,
        time_limit        = 20,
        g_tol             = 1e-8,
    ),
    kwargs...) where F
    cost, funs = coeff_cost_freq(Pd, Ps, freqs, vars)
    @show c0 = cost(x0)
    isfinite(c0) || error("Non-finite initial cost")
    @info "Starting optimization"
    sol = Optim.optimize(x->cost(exp.(x)), log.(x0), solver, opts)
    xopt = exp.(sol.minimizer)
    d = Dict(vars .=> xopt)
    # fun = OptimizationFunction(cost)
    # prob = OptimizationProblem(cost, x0; lb, ub, kwargs...)
    # sol = solve(prob, BBO(), maxiters=100000)
    # d = Dict(vars .=> sol.u)
    sort(d, by=string), sol, cost
end

function enforce_zero_noD!(P, ω)
    A,B,C,D = ssdata(P)
    Y = ControlSystems.isdiscrete(P) ? (cis(ω*P.Ts)*I - A)\B : (ω*I - A)\B
    X = C # dcgain = X*Y
    # find smalles dX such that (X + dX)*Y = 0
    # dX*Y = -X*Y
    dX = (-X*Y)*pinv(Y)
    @show norm(dX)
    Xo = X + dX
    Co = Xo
    # new dc gain = Xo*Y
    ω == 0 && @assert norm(Xo*Y) < sqrt(eps())
    P.C .= Co
    P
end




function fit_timedomain(datas, Ps, vars, x0s; solver = ParticleSwarm(), lb, ub, kwargs...)
    @info "Starting optimization"
    opts = Optim.Options(
        store_trace       = true,
        show_trace        = true,
        show_every        = 100,
        iterations        = 10000,
        allow_f_increases = false,
        time_limit        = 20,
        g_tol             = 1e-8,
    )
    sol = Optim.optimize(x->cost(exp.(x)), log.(x0), solver, opts)
    xopt = exp.(sol.minimizer)
    d = Dict(vars .=> xopt)
end

