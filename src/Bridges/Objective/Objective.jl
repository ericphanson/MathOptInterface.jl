module Objective

using MathOptInterface
const MOI = MathOptInterface
const MOIB = MOI.Bridges

# Definition of an objective bridge
include("bridge.jl")

# Mapping between objective function attributes and bridges
include("map.jl")

# Bridge optimizer bridging a specific objective bridge
include("single_bridge_optimizer.jl")

# Objective bridges
#include("zeros.jl")
#const Zeros{T, OT<:MOI.ModelLike} = SingleBridgeOptimizer{ZerosBridge{T}, OT}

"""
    add_all_bridges(bridged_model, T::Type)

Add all bridges defined in the `Bridges.Objective` submodule to `bridged_model`.
The coefficient type used is `T`.
"""
function add_all_bridges(bridged_model, T::Type)
#    MOIB.add_bridge(bridged_model, FunctionizeBridge{T})
    return
end

end
