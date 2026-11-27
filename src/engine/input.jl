const SDL_EVENT_BYTES = UInt32(56)
const SDL_EVENT_QUIT = UInt32(256)
const SDL_EVENT_KEYDOWN = UInt32(768)
const SDL_EVENT_KEYUP = UInt32(769)
const SDL_EVENT_MOUSEMOTION = UInt32(1024)
const SDL_EVENT_MOUSEBUTTONDOWN = UInt32(1025)
const SDL_EVENT_MOUSEBUTTONUP = UInt32(1026)

function poll_events()::Int32
    event_ptr::Ptr{SDL_Event} = Ptr{SDL_Event}(wasm_malloc(SDL_EVENT_BYTES))
    quit::Int32 = Int32(0)
    while llvm_SDL_PollEvent(event_ptr) != Int32(0)
        event_type::UInt32 = event_ptr.type
        key::Int32 = Int32(0)
        if event_type == SDL_EVENT_QUIT
            # Emscripten may deliver spurious QUIT before the first present TODO: handle
            quit = Int32(1)
        elseif event_type == SDL_EVENT_KEYDOWN
            # SDL_KeyboardEvent.repeat is the byte at offset 13. Skip OS key repeat.
            base_key::Ptr{UInt8} = Ptr{UInt8}(event_ptr)
            if unsafe_load(base_key + 13) == UInt8(0)
                key = Int32(event_ptr.key.keysym.sym)
                llvm_game_key_pressed(key)
            end
        elseif event_type == SDL_EVENT_KEYUP
            key = Int32(event_ptr.key.keysym.sym)
            llvm_game_key_released(key)
        elseif event_type == SDL_EVENT_MOUSEMOTION
            # x/y at bytes 20/24, xrel/yrel at 28/32. Window is 640x480, framebuffer 320x240.
            base::Ptr{UInt8} = Ptr{UInt8}(event_ptr)
            dx::Int32 = unsafe_load(Ptr{Int32}(base + 28))
            dy::Int32 = unsafe_load(Ptr{Int32}(base + 32))
            px::Int32 = div(unsafe_load(Ptr{Int32}(base + 20)) * SOFTWARE_WIDTH, Int32(640))
            py::Int32 = div(unsafe_load(Ptr{Int32}(base + 24)) * SOFTWARE_HEIGHT, Int32(480))
            llvm_game_pointer(px, py)
            llvm_game_mouse_moved(dx, dy)
        elseif event_type == SDL_EVENT_MOUSEBUTTONDOWN
            base = Ptr{UInt8}(event_ptr)
            button::Int32 = Int32(unsafe_load(base + 16))
            px = div(unsafe_load(Ptr{Int32}(base + 20)) * SOFTWARE_WIDTH, Int32(640))
            py = div(unsafe_load(Ptr{Int32}(base + 24)) * SOFTWARE_HEIGHT, Int32(480))
            llvm_game_pointer(px, py)
            llvm_game_mouse_pressed(button)
        elseif event_type == SDL_EVENT_MOUSEBUTTONUP
            base = Ptr{UInt8}(event_ptr)
            button = Int32(unsafe_load(base + 16))
            px = div(unsafe_load(Ptr{Int32}(base + 20)) * SOFTWARE_WIDTH, Int32(640))
            py = div(unsafe_load(Ptr{Int32}(base + 24)) * SOFTWARE_HEIGHT, Int32(480))
            llvm_game_pointer(px, py)
            llvm_game_mouse_released(button)
        end
    end
    wasm_free(Ptr{Cvoid}(event_ptr))
    return quit
end
