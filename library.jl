# Entry point for compile_library.jl (same pattern as sc-game/library.jl).
using StaticTools

include("structs.jl")

include("structs.jl")
include("llvm_functions.jl")
include("llvm_bindings.jl")
include("wallocstring.jl")
#include("static_constants.jl")
include("static_structs.jl")
include("static_helpers.jl")
include("hook_functions.jl")
include("static_functions.jl")
