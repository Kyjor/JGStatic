# Entry point for compile_library.jl (same pattern as sc-game/library.jl).
using StaticTools

include("common/constants.jl")
include("platform/structs.jl")

include("platform/llvm_functions.jl")
include("platform/llvm_bindings.jl")
include("common/wallocstring.jl")
#include("common/static_constants.jl")
include("common/static_structs.jl")
include("common/static_helpers.jl")
include("platform/hook_functions.jl")
include("scene/scene_json.jl")
include("scene/scene_load.jl")
include("engine/static_functions.jl")
