include("renderer.jl")
include("input.jl")
include("camera.jl")
include("entity.jl")
include("sprite.jl")

function init()::Int32
    init_flags::UInt32 = UInt32(SDL_INIT_VIDEO) | UInt32(SDL_INIT_AUDIO)
    if llvm_SDL_Init(init_flags) != Int32(0)
        return Int32(-1)
    end
    # IMG_INIT_PNG = 2
    if llvm_IMG_Init(Int32(2)) == Int32(0)
        return Int32(-1)
    end
    if llvm_Mix_OpenAudio(Int32(44100), UInt16(0x8010), Int32(2), Int32(2048)) != Int32(0)
        return Int32(-1)
    end
    return Int32(0)
end

function delay()
    llvm_SDL_Delay(UInt32(16))
    return
end

function game_loop()
    p::Ptr{Int32} = Ptr{Int32}(wasm_malloc(UInt32(4)))
    unsafe_store!(p, Int32(42))
    printf(unsafe_load(p))

    load()
    llvm_game_load()
    init()
    open_window(str_ptr(w"Test"))
    prepare_sprites()

    exit::Int32 = Int32(0)
    while exit == Int32(0)
        render_clear()
        exit = poll_events()
        llvm_game_update()
        draw()
        llvm_game_draw()

        render_present()
        delay()
    end

    llvm_game_shutdown()
end

function load()
    path::Ptr{UInt8} = str_ptr(w"scenes/scene.json")
    scene::Ptr{Scene} = llvm_load_scene(path)
    wasm_free(path)
    if scene == Ptr{Scene}(C_NULL)
        printf(c"scene load failed\n")
    end
    return
end

function jq_quit()::Bool



    return true
end
