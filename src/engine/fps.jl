# 3x5 digits. Each row is 3 bits, low bit is the left pixel.
struct FpsCounter
    last_ms::UInt32
    frames::Int32
    shown::Int32
    ready::Int32
    rect::Ptr{SDL_Rect}
    size_buf::Ptr{Int32}
end

function fps_slot(do_set::Int32, value::UInt64)::UInt64
    Base.llvmcall(("""
                   @g_fps = global i64 0
                   define i64 @main(i32 %do_set, i64 %value) {
                       entry:
                       %set = icmp ne i32 %do_set, 0
                       br i1 %set, label %write, label %read
                       write:
                       store i64 %value, i64* @g_fps
                       ret i64 %value
                       read:
                       %v = load i64, i64* @g_fps
                       ret i64 %v
                       }
                       """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end

function udiv_u32(n::UInt32, d::UInt32)::UInt32
    return Base.llvmcall(("""
                          define i32 @main(i32 %n, i32 %d) {
                              %q = udiv i32 %n, %d
                              ret i32 %q
                              }
                              """, "main"), UInt32, Tuple{UInt32, UInt32}, n, d)
end

function digit_bits(digit::Int32)::UInt32
    if digit == Int32(0)
        return UInt32(31599) # ### #.# #.# #.# ###
    elseif digit == Int32(1)
        return UInt32(29850) # .#. ##. .#. .#. ###
    elseif digit == Int32(2)
        return UInt32(29671) # ### ..# ### #.. ###
    elseif digit == Int32(3)
        return UInt32(31207) # ### ..# ### ..# ###
    elseif digit == Int32(4)
        return UInt32(18925) # #.# #.# ### ..# ..#
    elseif digit == Int32(5)
        return UInt32(31183) # ### #.. ### ..# ###
    elseif digit == Int32(6)
        return UInt32(31695) # ### #.. ### #.# ###
    elseif digit == Int32(7)
        return UInt32(18727) # ### ..# ..# ..# ..#
    elseif digit == Int32(8)
        return UInt32(31727) # ### #.# ### #.# ###
    elseif digit == Int32(9)
        return UInt32(31215) # ### #.# ### ..# ###
    end
    return UInt32(0)
end

function llvm_get_fps()::UInt64
    return Base.llvmcall(("""
                          declare i64 @fps_slot(i32, i64) nounwind
                          define i64 @main() {
                              entry:
                              %r = call i64 @fps_slot(i32 0, i64 0)
                              ret i64 %r
                              }
                              """, "main"), UInt64, Tuple{},)
end

function llvm_set_fps(value::UInt64)
    Base.llvmcall(("""
                   declare i64 @fps_slot(i32, i64) nounwind
                   define void @main(i64 %value) {
                       entry:
                       call i64 @fps_slot(i32 1, i64 %value)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{UInt64}, value)
    return
end

function fps_counter()::Ptr{FpsCounter}
    handle::UInt64 = llvm_get_fps()
    if handle != UInt64(0)
        return reinterpret(Ptr{FpsCounter}, handle)
    end
    counter::Ptr{FpsCounter} = Ptr{FpsCounter}(wasm_malloc(UInt32(sizeof(FpsCounter))))
    rect::Ptr{SDL_Rect} = Ptr{SDL_Rect}(wasm_malloc(UInt32(sizeof(SDL_Rect))))
    size_buf::Ptr{Int32} = Ptr{Int32}(wasm_malloc(UInt32(8)))
    if counter == Ptr{FpsCounter}(C_NULL) || rect == Ptr{SDL_Rect}(C_NULL) || size_buf == Ptr{Int32}(C_NULL)
        return Ptr{FpsCounter}(C_NULL)
    end
    unsafe_store!(counter, FpsCounter(llvm_SDL_GetTicks(), Int32(0), Int32(0), Int32(0), rect, size_buf))
    llvm_set_fps(reinterpret(UInt64, counter))
    return counter
end

function fill_screen_rect(renderer::Ptr{SDL_Renderer}, rect::Ptr{SDL_Rect}, x::Int32, y::Int32, w::Int32, h::Int32)
    unsafe_store!(rect, SDL_Rect(x, y, w, h))
    llvm_SDL_RenderFillRect(renderer, rect)
    return
end

function draw_digit(renderer::Ptr{SDL_Renderer}, rect::Ptr{SDL_Rect}, digit::Int32, x::Int32, y::Int32, scale::Int32)
    bits::UInt32 = digit_bits(digit)
    row::Int32 = Int32(0)
    while row < Int32(5)
        col::Int32 = Int32(0)
        while col < Int32(3)
            shift::UInt32 = UInt32(row * Int32(3) + col)
            if (bits & (UInt32(1) << shift)) != UInt32(0)
                fill_screen_rect(renderer, rect, x + col * scale, y + row * scale, scale, scale)
            end
            col += Int32(1)
        end
        row += Int32(1)
    end
    return
end

function draw_fps()
    renderer::Ptr{SDL_Renderer} = llvm_get_renderer()
    counter::Ptr{FpsCounter} = fps_counter()
    if renderer == Ptr{SDL_Renderer}(C_NULL) || counter == Ptr{FpsCounter}(C_NULL)
        return
    end
    state::FpsCounter = unsafe_load(counter)
    now::UInt32 = llvm_SDL_GetTicks()
    frames::Int32 = state.frames + Int32(1)
    shown::Int32 = state.shown
    ready::Int32 = state.ready
    last_ms::UInt32 = state.last_ms
    elapsed::UInt32 = now - last_ms
    if elapsed >= UInt32(500)
        shown = unsafe_trunc(Int32, udiv_u32(unsafe_trunc(UInt32, frames) * UInt32(1000), elapsed))
        if shown > Int32(999)
            shown = Int32(999)
        end
        if shown < Int32(0)
            shown = Int32(0)
        end
        frames = Int32(0)
        last_ms = now
        ready = Int32(1)
    end
    unsafe_store!(counter, FpsCounter(last_ms, frames, shown, ready, state.rect, state.size_buf))
    if ready == Int32(0)
        return
    end
    if llvm_SDL_GetRendererOutputSize(renderer, state.size_buf, elem_ptr(state.size_buf, Int32(1))) != Int32(0)
        return
    end
    screen_w::Int32 = unsafe_load(state.size_buf)
    scale::Int32 = Int32(3)
    margin::Int32 = Int32(8)
    pad::Int32 = Int32(4)
    count::Int32 = Int32(1)
    if shown >= Int32(100)
        count = Int32(3)
    elseif shown >= Int32(10)
        count = Int32(2)
    end
    digit_w::Int32 = Int32(3) * scale
    gap::Int32 = scale
    block_w::Int32 = count * digit_w + (count - Int32(1)) * gap
    block_h::Int32 = Int32(5) * scale
    x0::Int32 = screen_w - margin - block_w
    y0::Int32 = margin
    llvm_SDL_SetRenderDrawColor(renderer, UInt8(0), UInt8(0), UInt8(0), UInt8(255))
    fill_screen_rect(renderer, state.rect, x0 - pad, y0 - pad, block_w + pad * Int32(2), block_h + pad * Int32(2))
    llvm_SDL_SetRenderDrawColor(renderer, UInt8(255), UInt8(255), UInt8(255), UInt8(255))
    step::Int32 = digit_w + gap
    ones::Int32 = rem(shown, Int32(10))
    if count == Int32(1)
        draw_digit(renderer, state.rect, ones, x0, y0, scale)
    elseif count == Int32(2)
        draw_digit(renderer, state.rect, div(shown, Int32(10)), x0, y0, scale)
        draw_digit(renderer, state.rect, ones, x0 + step, y0, scale)
    else
        draw_digit(renderer, state.rect, div(shown, Int32(100)), x0, y0, scale)
        draw_digit(renderer, state.rect, rem(div(shown, Int32(10)), Int32(10)), x0 + step, y0, scale)
        draw_digit(renderer, state.rect, ones, x0 + step * Int32(2), y0, scale)
    end
    return
end
