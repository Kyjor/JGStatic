const RENDERER = Ptr{SDL_Renderer}(C_NULL)

function color_u8(value::Int32)::UInt8
    if value <= Int32(0)
        return UInt8(0)
    end
    if value >= Int32(255)
        return UInt8(255)
    end
    return unsafe_trunc(UInt8, value)
end

function open_window(name::Ptr{UInt8})::Int32
    width::Int32 = Int32(640)
    height::Int32 = Int32(480)
    scene::Ptr{Scene} = llvm_get_scene()
    if scene != Ptr{Scene}(C_NULL)
        cam::SceneCamera = scene.camera
        if cam.present == Int32(1) && cam.sx > 0.0 && cam.sy > 0.0
            width = f64_to_i32(cam.sx)
            height = f64_to_i32(cam.sy)
        end
    end
    window::Ptr{SDL_Window} = llvm_SDL_CreateWindow(name, Int32(0), Int32(0), width, height, UInt32(0))
    if window == Ptr{SDL_Window}(C_NULL)
        printf(c"Failed to create window\n")
        msg_ptr = wasm_malloc(UInt32(100))
        msg = llvm_SDL_GetErrorMsg(msg_ptr, Int32(100))
        printf(c"Error: %s\n", msg)
        wasm_free(Ptr{Cvoid}(msg_ptr))
    end

    flags::UInt32 = UInt32(SDL_RENDERER_ACCELERATED) #| UInt32(SDL_RENDERER_PRESENTVSYNC)
    renderer::Ptr{SDL_Renderer} = llvm_SDL_CreateRenderer(window, Int32(-1), flags)
    if renderer == Ptr{SDL_Renderer}(C_NULL)
        printf(c"Failed to create renderer\n")
    end
    llvm_set_renderer(renderer)
    create_software_frame(renderer)

    return Int32(-1)
end

function render_clear()
    renderer = llvm_get_renderer()
    red::UInt8 = UInt8(200)
    green::UInt8 = UInt8(220)
    blue::UInt8 = UInt8(255)
    alpha::UInt8 = UInt8(255)
    scene::Ptr{Scene} = llvm_get_scene()
    if scene != Ptr{Scene}(C_NULL)
        cam::SceneCamera = scene.camera
        if cam.present == Int32(1)
            red = color_u8(cam.br)
            green = color_u8(cam.bg)
            blue = color_u8(cam.bb)
            alpha = color_u8(cam.ba)
        end
    end
    llvm_SDL_SetRenderDrawColor(renderer, red, green, blue, alpha)
    llvm_SDL_RenderClear(renderer)
end

function render_present()
    renderer = llvm_get_renderer()
    llvm_SDL_RenderPresent(renderer)
end

function renderer_slot(do_set::Int32, value::UInt64)::UInt64
    Base.llvmcall(("""
                   @g_renderer = global i64 0
                   define i64 @main(i32 %do_set, i64 %value) {
                       entry:
                       %set = icmp ne i32 %do_set, 0
                       br i1 %set, label %write, label %read
                       write:
                       store i64 %value, i64* @g_renderer
                       ret i64 %value
                       read:
                       %v = load i64, i64* @g_renderer
                       ret i64 %v
                       }
                       """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end

function llvm_set_renderer(renderer::Ptr{SDL_Renderer})
    handle::UInt64 = reinterpret(UInt64, renderer)
    Base.llvmcall(("""
                   declare i64 @renderer_slot(i32, i64) nounwind

                   define void @main(i64 %value) {
                       entry:
                       call i64 @renderer_slot(i32 1, i64 %value)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{UInt64}, handle)
    return
end

function llvm_get_renderer()::Ptr{SDL_Renderer}
    handle::UInt64 = Base.llvmcall(("""
                                    declare i64 @renderer_slot(i32, i64) nounwind

                                    define i64 @main() {
                                        entry:
                                        %r = call i64 @renderer_slot(i32 0, i64 0)
                                        ret i64 %r
                                        }
                                        """, "main"), UInt64, Tuple{},)
    return reinterpret(Ptr{SDL_Renderer}, handle)
end
