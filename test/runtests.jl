using LogDensityUtilities
using Test
import LogDensityProblems: dimension, capabilities, logdensity, LogDensityOrder

####
#### general setup
####

abstract type TestLogDensities end

dimension(::TestLogDensities) = 3

capabilities(::Type{<:TestLogDensities}) = LogDensityOrder(1)

####
#### stress testing
####

Base.@kwdef mutable struct TestLogDensity1 <: TestLogDensities
    counter::Int = 0
end

function logdensity(ℓ::TestLogDensity1, x)
    ℓ.counter += 1
    if ℓ.counter ≤ 100
        sum(abs2, x) / 2
    else
        throw(DomainError(x))
    end
end

@testset "stress_test" begin
    results = stress_test(catch_errors(logdensity, TestLogDensity1()); N = 1000)
    @test sum(r -> r[2] isa DomainError, results) == 900
end
