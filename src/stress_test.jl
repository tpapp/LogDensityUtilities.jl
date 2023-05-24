export stress_test, catch_errors, check_gradient

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

Call `C(x)` with a random argument of conformable dimension. When the
result is `≢ nothing`, collect `x => result`, returning these.

See [`catch_errors`](@ref) and [`check_gradient`](@ref) for `C`.

# Keyword arguments (with defaults)

- `N = 1000`: the number of random trials

- `rng = default_rng()`: the random number generator to use

- `distribution = Distributions.TDist(2)`: a univariate or conforming multivariate
  distribution (needs to support `rand!(rng, distribution, x)`) to generate random coordinates.
"""
function stress_test(C; N = 1000, rng::AbstractRNG = default_rng(), distribution = TDist(2))
    x = zeros(stress_test_dimension(C))
    failures = Pair{Vector{Float64},Any}[]
    for _ in 1:N
        rand!(rng, x)
        result = C(x)
        result ≡ nothing || push!(failures, copy(x) => result)
    end
    failures
end

####
#### catch errors
####

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

####
#### check gradients
####

Base.@kwdef struct CheckGradient{L1,LS<:Tuple}
    ℓ1::L1
    ℓs::LS
    value_atol::Float64
    value_rtol::Float64
    gradient_atol::Float64
    gradient_rtol::Float64
end

stress_test_dimension(C::CheckGradient) = dimension(C.ℓ1)

"""
$(SIGNATURES)

Compare gradients of `ℓs` against `ℓ1`.

Keyword arguments control tolerances for comparisons.
"""
function check_gradient(ℓ1, ℓs...;
                        value_atol = 0.0, value_rtol = 0.0, gradient_atol = 1e-5, gradient_rtol = 1e-5)
    @argcheck value_atol ≥ 0
    @argcheck value_rtol ≥ 0
    @argcheck gradient_atol ≥ 0
    @argcheck gradient_rtol ≥ 0
    O1 = LogDensityOrder(1)
    @argcheck capabilities(ℓ1) ≥ O1
    @argcheck !isempty(ℓs)
    @argcheck all(ℓ -> capabilities(ℓ) ≥ O1, ℓs)
    d = dimension(ℓ1)
    @argcheck all(ℓ -> dimension(ℓ) ≥ d, ℓs)
    CheckGradient(; ℓ1, ℓs, value_atol = Float64(value_atol), value_rtol = Float64(value_rtol),
                  gradient_atol = Float64(gradient_atol), gradient_rtol = Float64(gradient_rtol))
end

function (C::CheckGradient)(x)
    @unpack ℓ1, ℓs, value_atol, value_rtol, gradient_atol, gradient_rtol = C
    v1, g1 = logdensity_and_gradient(ℓ1, x)
    for ℓ in ℓs
        v, g = logdensity_and_gradient(ℓ, x)
        isapprox(v1, v; atol = value_atol, rtol = value_rtol) || return :value_mismatch
        isapprox(g1, g; atol = gradient_atol, rtol = gradient_rtol) || return :gradient_mismatch
    end
    nothing
end
