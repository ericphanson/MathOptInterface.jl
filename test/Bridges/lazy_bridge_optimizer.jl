using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MathOptInterface.Test
const MOIU = MathOptInterface.Utilities
const MOIB = MathOptInterface.Bridges

include("utilities.jl")

MOIU.@model(
    LPModel,
    (), (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan), (), (),
    (), (MOI.ScalarAffineFunction,), (), ()
)

@testset "Name test" begin
    model = LPModel{Float64}()
    bridged = MOIB.full_bridge_optimizer(model, Float64)
    MOIT.nametest(bridged)
end

# Model similar to SDPA format, it gives a good example because it does not
# support a lot hence need a lot of bridges
MOIU.@model(SDPAModel,
            (), (MOI.EqualTo,), (MOI.Nonnegatives, MOI.PositiveSemidefiniteConeTriangle), (),
            (), (MOI.ScalarAffineFunction,), (MOI.VectorOfVariables,), ())
MOI.supports_constraint(::SDPAModel{T}, ::Type{MOI.SingleVariable}, ::Type{MOI.GreaterThan{T}}) where {T} = false
MOI.supports_constraint(::SDPAModel{T}, ::Type{MOI.SingleVariable}, ::Type{MOI.LessThan{T}}) where {T} = false
MOI.supports_constraint(::SDPAModel{T}, ::Type{MOI.SingleVariable}, ::Type{MOI.EqualTo{T}}) where {T} = false
MOI.supports_constraint(::SDPAModel, ::Type{MOI.VectorOfVariables}, ::Type{MOI.Reals}) = false

@testset "Name test" begin
    model = SDPAModel{Float64}()
    bridged = MOIB.full_bridge_optimizer(model, Float64)
    MOIT.nametest(bridged)
end

@testset "SDPA format with $T" for T in [Float64, Int]
    model = SDPAModel{T}()
    bridged = MOIB.LazyBridgeOptimizer(model)
    @testset "Nonpositives" begin
        @test !MOI.supports_constraint(model, MOI.VectorOfVariables, MOI.Nonpositives)
        @test !MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.Nonpositives)
        MOIB.add_bridge(bridged, MOIB.Variable.NonposToNonnegBridge{T})
        @test MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.Nonpositives)
        @test MOIB.bridge_type(bridged, MOI.Nonpositives) == MOIB.Variable.NonposToNonnegBridge{T}
    end
    @testset "Zeros" begin
        @test !MOI.supports_constraint(model, MOI.VectorOfVariables, MOI.Zeros)
        @test !MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.Zeros)
        MOIB.add_bridge(bridged, MOIB.Variable.ZerosBridge{T})
        @test MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.Zeros)
        @test MOIB.bridge_type(bridged, MOI.Zeros) == MOIB.Variable.ZerosBridge{T}
    end
    @testset "Free" begin
        @test !MOI.supports_constraint(model, MOI.VectorOfVariables, MOI.Reals)
        @test !MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.Reals)
        MOIB.add_bridge(bridged, MOIB.Variable.FreeBridge{T})
        @test MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.Reals)
        @test MOIB.bridge_type(bridged, MOI.Reals) == MOIB.Variable.FreeBridge{T}
    end
    @testset "Vectorize" begin
        @test !MOI.supports_constraint(model, MOI.SingleVariable, MOI.GreaterThan{T})
        @test !MOI.supports_constraint(bridged, MOI.SingleVariable, MOI.GreaterThan{T})
        @test !MOI.supports_constraint(model, MOI.SingleVariable, MOI.LessThan{T})
        @test !MOI.supports_constraint(bridged, MOI.SingleVariable, MOI.LessThan{T})
        @test !MOI.supports_constraint(model, MOI.SingleVariable, MOI.EqualTo{T})
        @test !MOI.supports_constraint(bridged, MOI.SingleVariable, MOI.EqualTo{T})
        MOIB.add_bridge(bridged, MOIB.Variable.VectorizeBridge{T})
        @test MOI.supports_constraint(bridged, MOI.SingleVariable, MOI.GreaterThan{T})
        @test MOIB.bridge_type(bridged, MOI.GreaterThan{T}) == MOIB.Variable.VectorizeBridge{T, MOI.Nonnegatives}
        @test MOI.supports_constraint(bridged, MOI.SingleVariable, MOI.LessThan{T})
        @test MOIB.bridge_type(bridged, MOI.LessThan{T}) == MOIB.Variable.VectorizeBridge{T, MOI.Nonpositives}
        @test MOI.supports_constraint(bridged, MOI.SingleVariable, MOI.EqualTo{T})
        @test MOIB.bridge_type(bridged, MOI.EqualTo{T}) == MOIB.Variable.VectorizeBridge{T, MOI.Zeros}
    end
    @testset "RSOCtoPSD" begin
        @test !MOI.supports_constraint(model, MOI.VectorOfVariables, MOI.RotatedSecondOrderCone)
        @test !MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.RotatedSecondOrderCone)
        MOIB.add_bridge(bridged, MOIB.Variable.RSOCtoPSDBridge{T})
        @test !MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.RotatedSecondOrderCone)
        MOIB.add_bridge(bridged, MOIB.Constraint.ScalarFunctionizeBridge{T})
        @test MOI.supports_constraint(bridged, MOI.VectorOfVariables, MOI.RotatedSecondOrderCone)
        @test MOIB.bridge_type(bridged, MOI.RotatedSecondOrderCone) == MOIB.Variable.RSOCtoPSDBridge{T}
    end
    @testset "Combining two briges" begin
        xy = MOI.add_variables(bridged, 2)
        test_delete_bridged_variables(bridged, xy, MOI.Reals, 2, (
            (MOI.VectorOfVariables, MOI.Nonnegatives, 0),
            (MOI.VectorOfVariables, MOI.Nonpositives, 0)),
            used_bridges = 2)
    end
end

@testset "Continuous Linear" begin
    model = SDPAModel{Float64}()
    bridged = MOIB.full_bridge_optimizer(model, Float64)
    exclude = ["partial_start"] # `VariablePrimalStart` not supported.
    MOIT.contlineartest(bridged, MOIT.TestConfig(solve=false), exclude)
end

@testset "Continuous Conic" begin
    model = SDPAModel{Float64}()
    bridged = MOIB.full_bridge_optimizer(model, Float64)
    exclude = ["exp", "pow", "logdet", "rootdets"]
    MOIT.contconictest(bridged, MOIT.TestConfig(solve=false), exclude)
end

# Model not supporting RotatedSecondOrderCone
MOIU.@model(NoRSOCModel,
            (),
            (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan),
            (MOI.Zeros, MOI.Nonnegatives, MOI.Nonpositives, MOI.SecondOrderCone,
             MOI.ExponentialCone, MOI.PositiveSemidefiniteConeTriangle),
            (MOI.PowerCone,),
            (),
            (MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction),
            (MOI.VectorOfVariables,),
            (MOI.VectorAffineFunction, MOI.VectorQuadraticFunction))

# Model not supporting VectorOfVariables and SingleVariable
MOIU.@model(NoVariableModel,
            (MOI.ZeroOne, MOI.Integer),
            (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan),
            (MOI.Zeros, MOI.Nonnegatives, MOI.Nonpositives, MOI.SecondOrderCone),
            (),
            (),
            (MOI.ScalarAffineFunction,),
            (),
            (MOI.VectorAffineFunction,))
function MOI.supports_constraint(::NoVariableModel, ::Type{MOI.SingleVariable},
                                 ::Type{<:MOI.AbstractScalarSet})
    return false
end

# Only supports GreaterThan and Nonnegatives
MOIU.@model(GreaterNonnegModel,
            (),
            (MOI.GreaterThan,),
            (MOI.Nonnegatives,),
            (),
            (),
            (MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction),
            (MOI.VectorOfVariables,),
            (MOI.VectorAffineFunction, MOI.VectorQuadraticFunction))
function MOI.supports_constraint(
    ::GreaterNonnegModel{T}, ::Type{MOI.SingleVariable},
    ::Type{<:Union{MOI.EqualTo{T}, MOI.LessThan{T}, MOI.Interval{T}}}) where T
    return false
end


MOIU.@model(ModelNoVAFinSOC,
            (),
            (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan, MOI.Interval),
            (MOI.Zeros, MOI.Nonnegatives, MOI.Nonpositives, MOI.SecondOrderCone,
             MOI.RotatedSecondOrderCone, MOI.GeometricMeanCone,
             MOI.PositiveSemidefiniteConeTriangle, MOI.ExponentialCone),
            (MOI.PowerCone, MOI.DualPowerCone),
            (),
            (MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction),
            (MOI.VectorOfVariables,),
            (MOI.VectorAffineFunction, MOI.VectorQuadraticFunction))

MOI.supports_constraint(::ModelNoVAFinSOC{Float64},
                        ::Type{MOI.VectorAffineFunction{Float64}},
                        ::Type{MOI.SecondOrderCone}) = false

# Model supporting nothing
MOIU.@model NothingModel () () () () () () () ()
function MOI.supports_constraint(
    ::NothingModel{T}, ::Type{MOI.SingleVariable},
    ::Type{<:Union{MOI.EqualTo{T}, MOI.GreaterThan{T}, MOI.LessThan{T},
                   MOI.Interval{T}, MOI.Integer, MOI.ZeroOne}}) where T
    return false
end

struct BridgeAddingNoConstraint{T} <: MOI.Bridges.Constraint.AbstractBridge end
MOIB.added_constrained_variable_types(::Type{<:BridgeAddingNoConstraint}) = Tuple{DataType}[]
MOIB.added_constraint_types(::Type{<:BridgeAddingNoConstraint}) = Tuple{DataType, DataType}[]
function MOI.supports_constraint(::Type{<:BridgeAddingNoConstraint},
                                 ::Type{MOI.SingleVariable},
                                 ::Type{MOI.Integer})
    return true
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:BridgeAddingNoConstraint{T}},
                                              ::Type{MOI.SingleVariable},
                                              ::Type{MOI.Integer}) where {T}
    return BridgeAddingNoConstraint{T}
end

const LessThanIndicatorSetOne{T} = MOI.IndicatorSet{MOI.ACTIVATE_ON_ONE, MOI.LessThan{T}}
MOIU.@model(ModelNoZeroIndicator,
            (MOI.ZeroOne, MOI.Integer),
            (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan, MOI.Interval,
             MOI.Semicontinuous, MOI.Semiinteger),
            (MOI.Reals, MOI.Zeros, MOI.Nonnegatives, MOI.Nonpositives,
             MOI.SecondOrderCone, MOI.RotatedSecondOrderCone,
             MOI.GeometricMeanCone, MOI.ExponentialCone, MOI.DualExponentialCone,
             MOI.PositiveSemidefiniteConeTriangle, MOI.PositiveSemidefiniteConeSquare,
             MOI.RootDetConeTriangle, MOI.RootDetConeSquare, MOI.LogDetConeTriangle,
             MOI.LogDetConeSquare),
            (MOI.PowerCone, MOI.DualPowerCone, MOI.SOS1, MOI.SOS2, LessThanIndicatorSetOne),
            (), (MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction),
            (MOI.VectorOfVariables,),
            (MOI.VectorAffineFunction, MOI.VectorQuadraticFunction))


@testset "Bridge adding no constraint" begin
    mock = MOIU.MockOptimizer(NothingModel{Int}())
    bridged = MOIB.LazyBridgeOptimizer(mock)
    MOI.Bridges.add_bridge(bridged, BridgeAddingNoConstraint{Float64})
    @test MOI.Bridges.supports_bridging_constraint(bridged,
                                                   MOI.SingleVariable,
                                                   MOI.Integer)
end

@testset "Unsupported constraint with cycles" begin
    # Test that `supports_constraint` works correctly when it is not
    # supported but the bridges forms a cycle
    mock = MOIU.MockOptimizer(NothingModel{Float64}())
    bridged = MOIB.full_bridge_optimizer(mock, Float64)
    @test !MOI.supports_constraint(
        bridged, MOI.SingleVariable, MOI.GreaterThan{Float64})
    @test !MOI.supports_constraint(
        bridged, MOI.VectorAffineFunction{Float64}, MOI.Nonpositives)
end

mock = MOIU.MockOptimizer(NoRSOCModel{Float64}())
bridged_mock = MOIB.LazyBridgeOptimizer(mock)

@testset "UnsupportedConstraint when it cannot be bridged" begin
    x = MOI.add_variables(bridged_mock, 4)
    err = MOI.UnsupportedConstraint{MOI.VectorOfVariables,
                                    MOI.RotatedSecondOrderCone}()
    @test_throws err begin
        MOI.add_constraint(bridged_mock, MOI.VectorOfVariables(x),
                           MOI.RotatedSecondOrderCone(4))
    end
end

MOIB.add_bridge(bridged_mock, MOIB.Constraint.SplitIntervalBridge{Float64})
MOIB.add_bridge(bridged_mock, MOIB.Constraint.RSOCtoPSDBridge{Float64})
MOIB.add_bridge(bridged_mock, MOIB.Constraint.SOCtoPSDBridge{Float64})
MOIB.add_bridge(bridged_mock, MOIB.Constraint.RSOCBridge{Float64})

@testset "Name test" begin
    MOIT.nametest(bridged_mock)
end

@testset "Copy test" begin
    MOIT.failcopytestc(bridged_mock)
    MOIT.failcopytestia(bridged_mock)
    MOIT.failcopytestva(bridged_mock)
    MOIT.failcopytestca(bridged_mock)
    MOIT.copytest(bridged_mock, NoRSOCModel{Float64}())
end

# Test that RSOCtoPSD is used instead of RSOC+SOCtoPSD as it is a shortest path.
@testset "Bridge selection" begin
    MOI.empty!(bridged_mock)
    @test !(MOI.supports_constraint(bridged_mock,
                                    MOI.VectorAffineFunction{Float64},
                                    MOI.LogDetConeTriangle))
    x = MOI.add_variables(bridged_mock, 3)
    err = MOI.UnsupportedConstraint{MOI.VectorAffineFunction{Float64},
                                    MOI.LogDetConeTriangle}()
    @test_throws err begin
        MOIB.bridge_type(bridged_mock, MOI.VectorAffineFunction{Float64},
                         MOI.LogDetConeTriangle)
    end
    c = MOI.add_constraint(bridged_mock, MOI.VectorOfVariables(x),
                           MOI.RotatedSecondOrderCone(3))
    @test MOIB.bridge_type(bridged_mock, MOI.VectorOfVariables,
                MOI.RotatedSecondOrderCone) == MOIB.Constraint.RSOCtoPSDBridge{Float64, MOI.VectorOfVariables}
    @test MOIB.bridge(bridged_mock, c) isa MOIB.Constraint.RSOCtoPSDBridge
    @test bridged_mock.constraint_dist[(MOI.VectorOfVariables,
                                        MOI.RotatedSecondOrderCone)] == 1
end

@testset "Supports" begin
    full_bridged_mock = MOIB.full_bridge_optimizer(mock, Float64)
    @testset "Mismatch vector/scalar" begin
        for S in [MOI.Nonnegatives, MOI.Nonpositives, MOI.Zeros]
            @test !MOI.supports_constraint(full_bridged_mock, MOI.SingleVariable, S)
        end
        for S in [MOI.GreaterThan{Float64}, MOI.LessThan{Float64}, MOI.EqualTo{Float64}]
            @test !MOI.supports_constraint(full_bridged_mock, MOI.VectorOfVariables, S)
        end
    end
    greater_nonneg_mock = MOIU.MockOptimizer(GreaterNonnegModel{Float64}())
    full_bridged_greater_nonneg = MOIB.full_bridge_optimizer(
        greater_nonneg_mock, Float64)
    for F in [MOI.SingleVariable, MOI.ScalarAffineFunction{Float64},
              MOI.ScalarQuadraticFunction{Float64}]
        @test MOI.supports_constraint(full_bridged_mock, F,
                                      MOI.Interval{Float64})
        @test !MOI.supports_constraint(
            greater_nonneg_mock, F, MOI.LessThan{Float64})
        @test MOI.supports_constraint(
            full_bridged_greater_nonneg, F, MOI.LessThan{Float64})
    end
    for F in [MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64},
              MOI.VectorQuadraticFunction{Float64}]
        @test MOI.supports_constraint(full_bridged_mock, F,
                                      MOI.PositiveSemidefiniteConeSquare)
        @test MOI.supports_constraint(full_bridged_mock, F,
                                      MOI.GeometricMeanCone)
        @test !MOI.supports_constraint(
            greater_nonneg_mock, F, MOI.Nonpositives)
        @test MOI.supports_constraint(
            full_bridged_greater_nonneg, F, MOI.Nonnegatives)
    end
    for F in [MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64}]
        # The bridges in this for loop do not support yet
        # VectorQuadraticFunction. See TODO's for the reason.
        # TODO: Missing vcat for quadratic for supporting quadratic.
        @test MOI.supports_constraint(full_bridged_mock, F,
                                      MOI.RotatedSecondOrderCone)
        # TODO: Det bridges need to use MOIU.operate to support quadratic.
        @test MOI.supports_constraint(full_bridged_mock, F,
                                      MOI.LogDetConeTriangle)
        @test MOI.supports_constraint(full_bridged_mock, F,
                                      MOI.RootDetConeTriangle)
    end
    mock2 = MOIU.MockOptimizer(ModelNoVAFinSOC{Float64}())
    @test !MOI.supports_constraint(mock2, MOI.VectorAffineFunction{Float64},
                                   MOI.SecondOrderCone)
    full_bridged_mock2 = MOIB.full_bridge_optimizer(mock2, Float64)
    @test MOI.supports_constraint(full_bridged_mock2, MOI.VectorAffineFunction{Float64},
                                  MOI.SecondOrderCone)
    mock_indicator = MOIU.MockOptimizer(ModelNoZeroIndicator{Float64}())
    full_bridged_mock_indicator = MOIB.full_bridge_optimizer(mock_indicator, Float64)
    @test !MOI.supports_constraint(mock_indicator, MOI.VectorAffineFunction{Float64},
                                MOI.IndicatorSet{MOI.ACTIVATE_ON_ZERO, MOI.LessThan{Float64}})
    @test MOI.supports_constraint(full_bridged_mock_indicator, MOI.VectorAffineFunction{Float64},
                                MOI.IndicatorSet{MOI.ACTIVATE_ON_ZERO, MOI.LessThan{Float64}})
    @testset "Unslack" begin
        for T in [Float64, Int]
            no_variable_mock = MOIU.MockOptimizer(NoVariableModel{T}())
            full_bridged_no_variable = MOIB.full_bridge_optimizer(
                no_variable_mock, T)
            for S in [MOI.LessThan{T}, MOI.GreaterThan{T}, MOI.EqualTo{T},
                      MOI.ZeroOne, MOI.Integer]
                @test MOI.supports_constraint(
                    full_bridged_no_variable, MOI.SingleVariable, S)
            end
            for S in [MOI.Nonpositives, MOI.Nonnegatives,
                      MOI.Zeros, MOI.SecondOrderCone]
                @test MOI.supports_constraint(
                    full_bridged_no_variable, MOI.VectorOfVariables, S)
            end
        end
    end
end
