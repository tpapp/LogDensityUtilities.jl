export stress_test, catch_errors

####
#### general setup
####

"""
$(SIGNATURES)

Return the dimension for stress test vectors. Internal.
"""
function stress_test_dimension end

"""
$(SIGNATURES)

Call `f(x)` with a random argument of conformable dimension. When the
result is `≢ nothing`, collect `x => result`, returning these.

See [`catch_errors`](@ref) for `f`.

# Keyword arguments (with defaults)

- `N = 1000`: the number of random trials

- `rng = default_rng()`: the random number generator to use

- `distribution = Distributions.TDist(2)`: a univariate or conforming multivariate
  distribution (needs to support `rand!(rng, distribution, x)`) to generate random coordinates.
"""
function stress_test(f; N = 1000, rng::AbstractRNG = default_rng(), distribution = TDist(2))
    x = zeros(stress_test_dimension(f))
    failures = Pair{Vector{Float64},Any}[]
    for _ in 1:N
        rand!(rng, x)
        result = f(x)
        result ≡ nothing || push!(failures, copy(x) => result)
    end
    failures
end

struct CatchErrors{F,L}
    f::F
    "log density problem"
    ℓ::L
    "whether to check for validity of results"
    test_invalid::Bool
end

"""
$(SIGNATURES)

Catch errors from calling `f(ℓ, x)`, where `f` is `logdensity`, `logdensity_and_gradient`,
or `logdensity_gradient_and_hessian`. The error will be collected.

When `test_invalid = true` (the default), also check the validity of the result, and collect
`:invalid`.
"""
function catch_errors(f, ℓ; test_invalid = true)
    CatchErrors(f, ℓ, test_invalid)
end

stress_test_dimension(C::CatchErrors) = dimension(C.ℓ)

function (C::CatchErrors)(x)
    @unpack f, ℓ, test_invalid = C
    try
        f(ℓ, x)
        # FIXME check for invalid once https://github.com/tpapp/LogDensityProblems.jl/pull/105
        # if is_valid_result(f(ℓ, x)...)
        #     nothing
        # else
        #     :invalid
        # end
        nothing
    catch e
        e
    end
end
