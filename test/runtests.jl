using LogDensityUtilities
using Test
import LogDensityProblems: dimension, capabilities, logdensity_and_gradient, LogDensityOrder

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

####
#### gradient comparison
####

function logdensity_and_gradient(ℓ::TestLogDensity1, x)
    v = sum(abs2, x) / 2
    g = x
    ℓ.counter += 1
    if ℓ.counter % 3 == 1
        v += 1                  # bad value
    elseif ℓ.counter % 3 == 2
        g = g .+ 1              # bad gradient
    end
    v, g
end

struct TestLogDensity2 <: TestLogDensities end

logdensity_and_gradient(::TestLogDensity2, x) = sum(abs2, x) / 2, x

@testset "check gradient" begin
    results = stress_test(check_gradient(TestLogDensity2(), TestLogDensity1()); N = 30)
    @test sum(x -> x[2] == :value_mismatch, results) == 10
    @test sum(x -> x[2] == :gradient_mismatch, results) == 10
end
