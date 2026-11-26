const SDL_EVENT_BYTES = UInt32(56)
const SDL_EVENT_QUIT = UInt32(256)
const SDL_EVENT_KEYDOWN = UInt32(768)
const SDL_EVENT_KEYUP = UInt32(769)
const SDL_EVENT_MOUSEMOTION = UInt32(1024)
const SDL_EVENT_MOUSEBUTTONDOWN = UInt32(1025)

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
            key = Int32(event_ptr.key.keysym.sym)
            llvm_game_key_pressed(key)
        elseif event_type == SDL_EVENT_KEYUP
            key = Int32(event_ptr.key.keysym.sym)
            llvm_game_key_released(key)
        elseif event_type == SDL_EVENT_MOUSEMOTION
            # xrel/yrel at bytes 28/32 of SDL_MouseMotionEvent. Avoid returning the struct.
            base::Ptr{UInt8} = Ptr{UInt8}(event_ptr)
            dx::Int32 = unsafe_load(Ptr{Int32}(base + 28))
            dy::Int32 = unsafe_load(Ptr{Int32}(base + 32))
            llvm_game_mouse_moved(dx, dy)
        elseif event_type == SDL_EVENT_MOUSEBUTTONDOWN
            base = Ptr{UInt8}(event_ptr)
            button::Int32 = Int32(unsafe_load(base + 16))
            llvm_game_mouse_pressed(button)
        end
    end
    wasm_free(Ptr{Cvoid}(event_ptr))
    return quit
end
