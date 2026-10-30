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

const RENDERER = Ptr{SDL_Renderer}(C_NULL)


function open_window(name::Ptr{UInt8})::Int32
   window::Ptr{SDL_Window} = llvm_SDL_CreateWindow(name, Int32(0), Int32(0), Int32(640), Int32(480), UInt32(0))
    if window == Ptr{SDL_Window}(C_NULL)
        printf(c"Failed to create window\n")
        msg_ptr = wasm_malloc(UInt32(100))
        msg = llvm_SDL_GetErrorMsg(msg_ptr, Int32(100))
        printf(c"Error: %s\n", msg)
        wasm_free(Ptr{Cvoid}(msg_ptr))
    end

    flags::UInt32 = UInt32(SDL_RENDERER_ACCELERATED) | UInt32(SDL_RENDERER_PRESENTVSYNC)
    renderer::Ptr{SDL_Renderer} = llvm_SDL_CreateRenderer(window, Int32(-1), flags)
    if renderer == Ptr{SDL_Renderer}(C_NULL)
        printf(c"Failed to create renderer\n")
    end
    llvm_set_renderer(renderer)

    return Int32(-1)
end


const SDL_EVENT_BYTES = UInt32(56)
const SDL_EVENT_QUIT = UInt32(256)
const SDL_EVENT_KEYDOWN = UInt32(768)
const SDL_EVENT_KEYUP = UInt32(769)

function poll_events()::Int32
    event_ptr::Ptr{SDL_Event} = Ptr{SDL_Event}(wasm_malloc(SDL_EVENT_BYTES))
    quit::Int32 = Int32(0)
    printf(RENDERER)
    while llvm_SDL_PollEvent(event_ptr) != Int32(0)
        event_type::UInt32 = event_ptr.type
        key::Int32 = Int32(0)
        if event_type == SDL_EVENT_QUIT
            # Emscripten may deliver spurious QUIT before the first present TODO: handle
            quit = Int32(1)
        elseif event_type == SDL_EVENT_KEYDOWN
            key = Int32(event_ptr.key.keysym.sym)
            printf(key)
        elseif event_type == SDL_EVENT_KEYUP
            key = Int32(event_ptr.key.keysym.sym)
        end
    end
    wasm_free(Ptr{Cvoid}(event_ptr))
    return quit
end

function delay()
    llvm_SDL_Delay(UInt32(16))
    return
end

function render_clear()
    renderer = llvm_get_renderer()
    llvm_SDL_SetRenderDrawColor(renderer, UInt8(200), UInt8(220), UInt8(255), UInt8(255))
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
