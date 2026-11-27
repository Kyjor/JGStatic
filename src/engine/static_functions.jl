include("renderer.jl")
include("raster.jl")
include("model.jl")
include("world3d.jl")
include("input.jl")
include("camera.jl")
include("entity.jl")
include("physics.jl")
include("sprite.jl")
include("fps.jl")

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

# 1 = keep running, 0 = quit, -1 = startup failed.
# Desktop stays in the loop. The browser calls this once per animation frame.
function game_loop()::Int32
    three_d::Int32 = llvm_game_wants_3d()
    if !JG_TARGET_WASM || llvm_clock_get() == UInt64(0)
        if three_d == Int32(0)
            load()
        end
        llvm_game_load()
        if init() != Int32(0)
            return Int32(-1)
        end
        if three_d == Int32(0)
            open_window(str_ptr(w"Test"))
            prepare_sprites()
        else
            open_window(str_ptr(w"Raid"))
            init_world3d()
        end
        llvm_clock_set(llvm_SDL_GetPerformanceCounter())
    end

    exit::Int32 = Int32(0)
    while exit == Int32(0)
        render_clear()
        exit = poll_events()
        if exit != Int32(0)
            break
        end

        # update game
        now::UInt64 = llvm_SDL_GetPerformanceCounter()
        last::UInt64 = llvm_clock_get()
        llvm_clock_set(now)
        dt::Float64 = 0.0
        freq::UInt64 = llvm_SDL_GetPerformanceFrequency()
        if last != UInt64(0) && freq != UInt64(0) && now > last
            dt = Float64(now - last) / Float64(freq)
        end
        llvm_game_update(dt)

        # update physics
        if three_d == Int32(0)
            physics_step(dt)
        end
        llvm_game_late_update()

        # draw game
        if three_d == Int32(0)
            draw()
            llvm_game_draw()
           
        else
            render_world3d(dt)
        end
        draw_fps()
        render_present()
       # delay()
        if JG_TARGET_WASM
            return Int32(1)
        end
    end

    llvm_game_shutdown()
    return Int32(0)
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
