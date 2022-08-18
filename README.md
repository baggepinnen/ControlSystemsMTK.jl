# ControlSystemsMTK

[![Build Status](https://github.com/baggepinnen/ControlSystemsMTK.jl/workflows/CI/badge.svg)](https://github.com/baggepinnen/ControlSystemsMTK.jl/actions)
[![Coverage](https://codecov.io/gh/baggepinnen/ControlSystemsMTK.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/baggepinnen/ControlSystemsMTK.jl)

An experimental interface between [ControlSystems.jl](https://github.com/JuliaControl/ControlSystems.jl) and [ModelingToolkit.jl](https://github.com/SciML/ModelingToolkit.jl).

See the video below, at 17:30, for an example of using ControlSystems and ModelingToolkit together
[![CS and MTK on youtube](https://img.youtube.com/vi/favQKOyyx4o/0.jpg)](https://www.youtube.com/watch?v=favQKOyyx4o)


## From ControlSystems to ModelingToolkit
Simply calling `ODESystem(sys)` converts a `StateSpace` object from ControlSystems into the corresponding [`ModelingToolkitStandardLibrary.Blocks.StateSpace`](http://mtkstdlib.sciml.ai/dev/API/blocks/#ModelingToolkitStandardLibrary.Blocks.StateSpace). If `sys` is a named statespace object, the names will be retained in the `ODESystem`.

### Example:

```julia
julia> using ControlSystemsMTK, ControlSystems, ModelingToolkit, RobustAndOptimalControl

julia> P0 = tf(1.0, [1, 1])  |> ss
StateSpace{Continuous, Float64}
A = 
 -1.0
B = 
 1.0
C = 
 1.0
D = 
 0.0

Continuous-time state-space model

julia> @named P = ODESystem(P0)
Model P with 2 equations
States (3):
  x[1](t) [defaults to 0.0]
  input₊u(t) [defaults to 0.0]
  output₊u(t) [defaults to 0.0]
Parameters (0):

julia> equations(P)
2-element Vector{Equation}:
 Differential(t)(x[1](t)) ~ input₊u(t) - x[1](t)
 output₊u(t) ~ x[1](t)
```


## From ModelingToolkit to ControlSystems
An `ODESystem` can be converted to a named statespace object from [RobustAndOptimalControl.jl](https://github.com/JuliaControl/RobustAndOptimalControl.jl) by calling

```julia
named_ss(ode_sys, inputs, outputs; op)
```
this performs a linearization of `ode_sys` around the operating point `op` (defaults to the default values of all variables in `ode_sys`).


### Example:
Using `P` from above:
```julia
julia> @unpack input, output = P;

julia> P02_named = named_ss(P, [input.u], [output.u])
NamedStateSpace{Continuous, Float64}
A = 
 -1.0
B = 
 1.0
C = 
 1.0
D = 
 0.0

Continuous-time state-space model
With state  names: x[1](t)
     input  names: input₊u(t)
     output names: output₊u(t)

julia> using Plots;

julia> bodeplot(P02_named)
```
![plot](https://user-images.githubusercontent.com/3797491/184320765-6303b2db-ad85-4514-8b9e-d3d822b5561c.png)
```julia
julia> ss(P02_named) # Convert to a statespace system without names
StateSpace{Continuous, Float64}
A = 
 -1.0
B = 
 1.0
C = 
 1.0
D = 
 0.0

Continuous-time state-space model
```

ModelingToolkit tends to give weird names to states etc., to access variables easily, `named_ss` [implements prefix matching](https://juliacontrol.github.io/RobustAndOptimalControl.jl/dev/#Named-systems), so that you can access the state `x[1](t)` by `P02_named.x`:
```julia
julia> P02_named.x
1-element Vector{Symbol}:
 Symbol("x[1](t)")
```