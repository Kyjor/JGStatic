# Build lib_desktop/libjg_static.* from Julia (no SDL).
# Pattern: functions list + .o merge + shared lib only.
#
# Usage (from this directory):
#   julia --project=. compile_library.jl desktop
#   ./build_host.sh
#   ./build_web.sh
#
# Needs Julia 1.11 + StaticCompiler from this folder's Project.toml (not global 0.7.2).

using Pkg
const STATIC_ROOT = @__DIR__
if isfile(joinpath(STATIC_ROOT, "Project.toml"))
    Pkg.activate(STATIC_ROOT)
    Pkg.instantiate()
end

using StaticTools
using StaticCompiler

build_type = length(ARGS) > 0 ? lowercase(ARGS[1]) : "desktop"
build_type in ("web", "desktop") || error("Usage: julia --project=. compile_library.jl [web|desktop]")
# wasm32 libc uses 32-bit long and size_t. scene_load.jl reads this before emitting file IO calls.
const JG_TARGET_WASM = build_type == "web"

compile_file = get(ENV, "FILE", "library.jl")
include(joinpath(STATIC_ROOT, compile_file))

lib_base = get(ENV, "LIB_NAME", "jg_static")
output_dir = build_type == "web" ? "lib_wasm" : "lib_desktop"
isdir(output_dir) || mkdir(output_dir)

println("📚 Compiling Julia library for $build_type")
println("   Julia $(VERSION.major).$(VERSION.minor).$(VERSION.patch)")
println("   StaticCompiler $(pkgversion(StaticCompiler))")
println("=" ^ 50)

println("🧹 Cleaning up old files...")
for file in readdir(output_dir)
    # Keep hand-maintained headers out of lib_*; jg_static.h lives in Static/
    if endswith(file, ".ll") || endswith(file, ".o") || endswith(file, ".so") ||
       endswith(file, ".dll") || endswith(file, ".dylib") || endswith(file, ".a")
        rm(joinpath(output_dir, file))
        println("🗑️  Removed: $file")
    end
end

const _BATCH_SIG = (
    Int32, Int32,
    Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Ptr{Int32},
    Int32,
)

include("functions_table.jl")

compile_ok = true
for (func, types, name) in functions_to_compile
    println(" Compiling $name...")
    try
        if build_type == "web"
            StaticCompiler.generate_obj(func, types, output_dir, name, emit_llvm_only=true)
            println("✅ Generated: $output_dir/$name.ll")
        else
            StaticCompiler.generate_obj(func, types, output_dir, name, emit_llvm_only=false)
            println("✅ Generated: $output_dir/$name.o")
        end
    catch e
        global compile_ok = false
        println("❌ Error compiling $name: $e")
        if occursin("validate_code_in_debug_mode", string(e))
            println("💡 Use: julia --project=$(STATIC_ROOT) compile_library.jl desktop")
            println("   (global StaticCompiler 0.7.2 does not support Julia 1.11)")
        end
    end
end

function resolve_emscripten_llvm_link()
    emcc = Sys.which("emcc")
    emcc === nothing && return nothing
    p = abspath(emcc)
    while islink(p)
        link = readlink(p)
        p = startswith(link, "/") ? link : joinpath(dirname(p), link)
        p = abspath(p)
    end
    emdir = dirname(dirname(p))
    for candidate in (
        joinpath(emdir, "libexec", "llvm", "bin", "llvm-link"),
        joinpath(emdir, "llvm", "bin", "llvm-link"),
    )
        isfile(candidate) && return candidate
    end
    return nothing
end

function resolve_llvm_link()
    if haskey(ENV, "LLVM_LINK") && isfile(ENV["LLVM_LINK"])
        return ENV["LLVM_LINK"]
    end
    em = resolve_emscripten_llvm_link()
    em !== nothing && return em
    w = Sys.which("llvm-link")
    w !== nothing && return w
    for candidate in (
        "/opt/homebrew/opt/llvm/bin/llvm-link",
        "/usr/local/opt/llvm/bin/llvm-link",
    )
        isfile(candidate) && return candidate
    end
    return nothing
end

# Julia IR lifetime intrinsics can disagree with emscripten's clang after foreign llvm-link.
function sanitize_ll_for_emscripten(ir::String)::String
    join(filter(!contains("llvm.lifetime"), split(ir, '\n', keepempty=true)), '\n')
end

if build_type == "web"
    compile_ok || exit(1)
    println("\n🔨 Linking WebAssembly (engine + game/game.c)...")

    game_wasm_dir = joinpath(STATIC_ROOT, "game_wasm")
    isdir(game_wasm_dir) || mkdir(game_wasm_dir)

    ll_files = String[]
    for file in readdir(output_dir)
        endswith(file, ".ll") && push!(ll_files, joinpath(output_dir, file))
    end
    isempty(ll_files) && error("No .ll files in $output_dir")

    combined_ll = joinpath(output_dir, "combined.ll")
    llvm_link = resolve_llvm_link()
    llvm_link === nothing && error("llvm-link not found — install Emscripten or: brew install llvm")
    run(Cmd(vcat([llvm_link, "-S", "-o", combined_ll], ll_files)))
    combined_content = read(combined_ll, String)
    combined_content = replace(combined_content, r"target triple = \"[^\"]+\"" => "target triple = \"wasm32-unknown-emscripten\"")
    combined_content = sanitize_ll_for_emscripten(combined_content)
    write(combined_ll, combined_content)
    println("✅ Combined LLVM IR: $combined_ll")

    game_js = joinpath(game_wasm_dir, "game.js")
    emcc = Sys.which("emcc")
    emcc === nothing && error("emcc not found — install Emscripten and source emsdk_env.sh")
    run(Cmd([
        emcc, combined_ll,
        joinpath(STATIC_ROOT, "game", "game.c"),
        joinpath(STATIC_ROOT, "jg_static_runtime.c"),
        "-DJG_NO_MAIN",
        "-O2",
        "-sUSE_SDL=2",
        "-sUSE_SDL_IMAGE=2",
        "-sSDL2_IMAGE_FORMATS=[\"png\"]",
        "-sUSE_SDL_MIXER=2",
        "-sUSE_OGG=1",
        "-sUSE_WEBGL2=1",
        "-sWASM=1",
        "-sALLOW_MEMORY_GROWTH=1",
        "-sINITIAL_MEMORY=67108864",
        "-sALLOW_TABLE_GROWTH=1",
        "-sSTACK_SIZE=1048576",
        "-sEXPORTED_FUNCTIONS=['_game_loop','_malloc','_free']",
        "-sEXPORTED_RUNTIME_METHODS=['cwrap']",
        "--no-entry",
        "--preload-file", joinpath(STATIC_ROOT, "game", "assets") * "@/assets",
        "--preload-file", joinpath(STATIC_ROOT, "game", "scenes") * "@/scenes",
        "--use-preload-plugins",
        "-o", game_js,
    ]))
    println("✅ WebAssembly: $game_js")
    println("   $(game_wasm_dir)/game.wasm")
    println("\n💡 Serve this directory and open index.html:")
    println("   python3 -m http.server")
    exit(0)
end

if !compile_ok
    println("\n❌ One or more functions failed to compile — not linking.")
    exit(1)
end

run_cmd(exe::String, args::Vector{String}) = run(Cmd(vcat([exe], args)))

println("\n🔨 Bundling native library (Julia .o + jg_static_runtime.c, no SDL)...")

runtime_c = joinpath(STATIC_ROOT, "jg_static_runtime.c")
runtime_o = joinpath(output_dir, "jg_static_runtime.o")
println(" Compiling jg_static_runtime.c...")
run_cmd("gcc", ["-c", "-O3", "-fPIC", "-o", runtime_o, runtime_c])

julia_o_files = String[]
for file in readdir(output_dir)
    endswith(file, ".o") || continue
    # Keep runtime .o separate; merge Julia objects only
    basename(file) == "jg_static_runtime.o" && continue
    push!(julia_o_files, joinpath(output_dir, file))
end

if isempty(julia_o_files)
    println("❌ No .o files in $output_dir — compile step produced nothing.")
    exit(1)
end

merged_o = joinpath(output_dir, "$(lib_base)_merged.o")
opt_c = ["-O3", "-flto", "-fPIC"]
if length(julia_o_files) == 1
    cp(julia_o_files[1], merged_o; force=true)
else
    run_cmd("gcc", vcat(opt_c, ["-r", "-o", merged_o], julia_o_files))
end

static_lib = joinpath(output_dir, "lib$(lib_base).a")
run_cmd("ar", ["rcs", static_lib, merged_o, runtime_o])
println("✅ Static archive: $static_lib")

if Sys.iswindows()
    lib_name = "$(lib_base).dll"
    system_libs = String[]
elseif Sys.isapple()
    lib_name = "lib$(lib_base).dylib"
    system_libs = ["-Wl,-undefined,dynamic_lookup"]
else
    lib_name = "lib$(lib_base).so"
    system_libs = ["-ldl", "-lpthread", "-lm"]
end

lib_path = joinpath(output_dir, lib_name)
# Linux: DT_SONAME. macOS: ld records the -o path (lib_desktop/libjg_static.dylib)
# unless -install_name is set; @rpath is what the game binary's -rpath resolves.
soname = if Sys.islinux()
    ["-Wl,-soname,$lib_name"]
elseif Sys.isapple()
    ["-Wl,-install_name,@rpath/$lib_name"]
else
    String[]
end
# No -flto on final link: mix LTO Julia .o with non-LTO C runtime.
run_cmd("gcc", vcat(["-shared", "-O3", "-fPIC"], soname, ["-o", lib_path, merged_o, runtime_o], system_libs))
println("✅ Shared library: $lib_path")
println("\n💡 Verify: ./build_host.sh")
