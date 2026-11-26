# Software framebuffer. The color bytes are what a file-writing tutorial would save.
# Each frame they are uploaded to an SDL texture and copied over the window.

const SOFTWARE_WIDTH = Int32(320)
const SOFTWARE_HEIGHT = Int32(240)

struct SoftwareFrame
    texture::Ptr{SDL_Texture}
    color::Ptr{UInt8}
    depth::Ptr{Float64}
    width::Int32
    height::Int32
end

function software_frame_slot(do_set::Int32, value::UInt64)::UInt64
    Base.llvmcall(("""
                   @g_software_frame = global i64 0
                   define i64 @main(i32 %do_set, i64 %value) {
                       entry:
                       %set = icmp ne i32 %do_set, 0
                       br i1 %set, label %write, label %read
                       write:
                       store i64 %value, i64* @g_software_frame
                       ret i64 %value
                       read:
                       %v = load i64, i64* @g_software_frame
                       ret i64 %v
                       }
                       """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end

function llvm_set_software_frame(frame::Ptr{SoftwareFrame})
    handle::UInt64 = reinterpret(UInt64, frame)
    Base.llvmcall(("""
                   declare i64 @software_frame_slot(i32, i64) nounwind
                   define void @main(i64 %value) {
                       entry:
                       call i64 @software_frame_slot(i32 1, i64 %value)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{UInt64}, handle)
    return
end

function llvm_get_software_frame()::Ptr{SoftwareFrame}
    handle::UInt64 = Base.llvmcall(("""
                                    declare i64 @software_frame_slot(i32, i64) nounwind
                                    define i64 @main() {
                                        entry:
                                        %r = call i64 @software_frame_slot(i32 0, i64 0)
                                        ret i64 %r
                                        }
                                        """, "main"), UInt64, Tuple{},)
    return reinterpret(Ptr{SoftwareFrame}, handle)
end

function create_software_frame(renderer::Ptr{SDL_Renderer})
    if renderer == Ptr{SDL_Renderer}(C_NULL)
        return
    end
    width::Int32 = SOFTWARE_WIDTH
    height::Int32 = SOFTWARE_HEIGHT
    color_bytes::UInt32 = UInt32(width) * UInt32(height) * UInt32(4)
    depth_bytes::UInt32 = UInt32(width) * UInt32(height) * UInt32(8)
    color::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(color_bytes))
    depth::Ptr{Float64} = Ptr{Float64}(wasm_malloc(depth_bytes))
    # SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING
    texture::Ptr{SDL_Texture} = llvm_SDL_CreateTexture(renderer, UInt32(376840196), Int32(1), width, height)
    # SDL_BLENDMODE_NONE. A blended texture with a zero alpha byte stays invisible.
    llvm_SDL_SetTextureBlendMode(texture, UInt32(0))
    if color == Ptr{UInt8}(C_NULL) || depth == Ptr{Float64}(C_NULL) || texture == Ptr{SDL_Texture}(C_NULL)
        printf(c"software frame alloc failed\n")
        return
    end
    frame::Ptr{SoftwareFrame} = Ptr{SoftwareFrame}(wasm_malloc(UInt32(sizeof(SoftwareFrame))))
    if frame == Ptr{SoftwareFrame}(C_NULL)
        printf(c"software frame alloc failed\n")
        return
    end
    unsafe_store!(frame, SoftwareFrame(texture, color, depth, width, height))
    llvm_set_software_frame(frame)
    return
end

function clear_software(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32)
    count::Int32 = width * height
    i::Int32 = Int32(0)
    while i < count
        pixel::Ptr{UInt8} = color + (Int(i) * 4)
        unsafe_store!(pixel, UInt8(36))
        unsafe_store!(pixel + 1, UInt8(40))
        unsafe_store!(pixel + 2, UInt8(58))
        unsafe_store!(pixel + 3, UInt8(255))
        unsafe_store!(elem_ptr(depth, i), 0.0)
        i = i + Int32(1)
    end
    return
end

function plot_software(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, x::Int32, y::Int32, z::Float64, red::UInt8, green::UInt8, blue::UInt8)
    if x < Int32(0) || y < Int32(0) || x >= width || y >= height
        return
    end
    if z <= 0.0
        return
    end
    index::Int32 = y * width + x
    invz::Float64 = 1.0 / z
    if invz <= unsafe_load(elem_ptr(depth, index))
        return
    end
    unsafe_store!(elem_ptr(depth, index), invz)
    pixel::Ptr{UInt8} = color + (Int(index) * 4)
    unsafe_store!(pixel, red)
    unsafe_store!(pixel + 1, green)
    unsafe_store!(pixel + 2, blue)
    unsafe_store!(pixel + 3, UInt8(255))
    return
end

function edge_cross(ax::Int32, ay::Int32, bx::Int32, by::Int32, px::Int32, py::Int32)::Int32
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax)
end

function draw_triangle_screen(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, x0::Int32, y0::Int32, z0::Float64, x1::Int32, y1::Int32, z1::Float64, x2::Int32, y2::Int32, z2::Float64, red::UInt8, green::UInt8, blue::UInt8)
    area::Int32 = edge_cross(x0, y0, x1, y1, x2, y2)
    if area == Int32(0)
        return
    end
    minx::Int32 = x0
    maxx::Int32 = x0
    miny::Int32 = y0
    maxy::Int32 = y0
    if x1 < minx
        minx = x1
    end
    if x2 < minx
        minx = x2
    end
    if x1 > maxx
        maxx = x1
    end
    if x2 > maxx
        maxx = x2
    end
    if y1 < miny
        miny = y1
    end
    if y2 < miny
        miny = y2
    end
    if y1 > maxy
        maxy = y1
    end
    if y2 > maxy
        maxy = y2
    end
    if minx < Int32(0)
        minx = Int32(0)
    end
    if miny < Int32(0)
        miny = Int32(0)
    end
    if maxx >= width
        maxx = width - Int32(1)
    end
    if maxy >= height
        maxy = height - Int32(1)
    end
    y::Int32 = miny
    while y <= maxy
        x::Int32 = minx
        while x <= maxx
            w0::Int32 = edge_cross(x1, y1, x2, y2, x, y)
            w1::Int32 = edge_cross(x2, y2, x0, y0, x, y)
            w2::Int32 = edge_cross(x0, y0, x1, y1, x, y)
            hit::Int32 = Int32(0)
            if area > Int32(0)
                if w0 >= Int32(0) && w1 >= Int32(0) && w2 >= Int32(0)
                    hit = Int32(1)
                end
            else
                if w0 <= Int32(0) && w1 <= Int32(0) && w2 <= Int32(0)
                    hit = Int32(1)
                end
            end
            if hit != Int32(0)
                zz::Float64 = (Float64(w0) * z0 + Float64(w1) * z1 + Float64(w2) * z2) / Float64(area)
                plot_software(color, depth, width, height, x, y, zz, red, green, blue)
            end
            x = x + Int32(1)
        end
        y = y + Int32(1)
    end
    return
end

function draw_software_frame()
    frame_ptr::Ptr{SoftwareFrame} = llvm_get_software_frame()
    if frame_ptr == Ptr{SoftwareFrame}(C_NULL)
        return
    end
    frame::SoftwareFrame = unsafe_load(frame_ptr)
    if frame.texture == Ptr{SDL_Texture}(C_NULL) || frame.color == Ptr{UInt8}(C_NULL) || frame.depth == Ptr{Float64}(C_NULL)
        return
    end
    clear_software(frame.color, frame.depth, frame.width, frame.height)
    draw_triangle_screen(frame.color, frame.depth, frame.width, frame.height, Int32(160), Int32(30), 0.0, Int32(30), Int32(210), 0.0, Int32(290), Int32(210), 0.0, UInt8(180), UInt8(48), UInt8(36))
    pitch::Int32 = frame.width * Int32(4)
    llvm_SDL_UpdateTexture(frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{Cvoid}(frame.color), pitch)
    llvm_SDL_RenderCopy(llvm_get_renderer(), frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{SDL_Rect}(C_NULL))
    return
end
