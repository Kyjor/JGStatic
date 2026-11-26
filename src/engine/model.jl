# Wavefront mesh. The subject is game/assets/models/head.obj
# (the african head from the tinyrenderer course).

struct Mesh
    positions::Ptr{Float64}
    indices::Ptr{Int32}
    vert_count::Int32
    tri_count::Int32
    cx::Float64
    cy::Float64
    cz::Float64
    radius::Float64
end

function mesh_slot(do_set::Int32, value::UInt64)::UInt64
    Base.llvmcall(("""
                   @g_mesh = global i64 0
                   define i64 @main(i32 %do_set, i64 %value) {
                       entry:
                       %set = icmp ne i32 %do_set, 0
                       br i1 %set, label %write, label %read
                       write:
                       store i64 %value, i64* @g_mesh
                       ret i64 %value
                       read:
                       %v = load i64, i64* @g_mesh
                       ret i64 %v
                       }
                       """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end

function llvm_set_mesh(mesh::Ptr{Mesh})
    handle::UInt64 = reinterpret(UInt64, mesh)
    Base.llvmcall(("""
                   declare i64 @mesh_slot(i32, i64) nounwind
                   define void @main(i64 %value) {
                       entry:
                       call i64 @mesh_slot(i32 1, i64 %value)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{UInt64}, handle)
    return
end

function llvm_get_mesh()::Ptr{Mesh}
    handle::UInt64 = Base.llvmcall(("""
                                    declare i64 @mesh_slot(i32, i64) nounwind
                                    define i64 @main() {
                                        entry:
                                        %r = call i64 @mesh_slot(i32 0, i64 0)
                                        ret i64 %r
                                        }
                                        """, "main"), UInt64, Tuple{},)
    return reinterpret(Ptr{Mesh}, handle)
end

function obj_at(data::Ptr{UInt8}, pos::UInt32)::UInt8
    return unsafe_load(data + Int(pos))
end

function skip_line(data::Ptr{UInt8}, len::UInt32, pos::UInt32)::UInt32
    while pos < len
        c::UInt8 = obj_at(data, pos)
        pos = pos + UInt32(1)
        if c == UInt8('\n')
            return pos
        end
    end
    return pos
end

function skip_spaces(data::Ptr{UInt8}, len::UInt32, pos::UInt32)::UInt32
    while pos < len
        c::UInt8 = obj_at(data, pos)
        if c != UInt8(' ') && c != UInt8('\t') && c != UInt8('\r')
            return pos
        end
        pos = pos + UInt32(1)
    end
    return pos
end

# Position comes back through pos_out. A returned struct that mixes a float and ints
# does not survive StaticCompiler, which zeroed every vertex.
function scan_f64(data::Ptr{UInt8}, len::UInt32, pos::UInt32, pos_out::Ptr{UInt32})::Float64
    pos = skip_spaces(data, len, pos)
    if pos >= len
        unsafe_store!(pos_out, pos)
        return 0.0
    end
    sign::Float64 = 1.0
    c::UInt8 = obj_at(data, pos)
    if c == UInt8('-')
        sign = -1.0
        pos = pos + UInt32(1)
    elseif c == UInt8('+')
        pos = pos + UInt32(1)
    end
    whole::Float64 = 0.0
    frac::Float64 = 0.0
    place::Float64 = 1.0
    saw::Int32 = Int32(0)
    dotted::Int32 = Int32(0)
    while pos < len
        c = obj_at(data, pos)
        if c >= UInt8('0') && c <= UInt8('9')
            saw = Int32(1)
            digit::Float64 = Float64(c - UInt8('0'))
            if dotted == Int32(0)
                whole = whole * 10.0 + digit
            else
                place = place * 0.1
                frac = frac + digit * place
            end
            pos = pos + UInt32(1)
        elseif c == UInt8('.') && dotted == Int32(0)
            dotted = Int32(1)
            pos = pos + UInt32(1)
        else
            break
        end
    end
    unsafe_store!(pos_out, pos)
    if saw == Int32(0)
        return 0.0
    end
    return sign * (whole + frac)
end

function scan_i32(data::Ptr{UInt8}, len::UInt32, pos::UInt32, pos_out::Ptr{UInt32}, ok_out::Ptr{Int32})::Int32
    pos = skip_spaces(data, len, pos)
    if pos >= len
        unsafe_store!(pos_out, pos)
        unsafe_store!(ok_out, Int32(0))
        return Int32(0)
    end
    sign::Int32 = Int32(1)
    c::UInt8 = obj_at(data, pos)
    if c == UInt8('-')
        sign = Int32(-1)
        pos = pos + UInt32(1)
    elseif c == UInt8('+')
        pos = pos + UInt32(1)
    end
    if pos >= len
        unsafe_store!(pos_out, pos)
        unsafe_store!(ok_out, Int32(0))
        return Int32(0)
    end
    c = obj_at(data, pos)
    if c < UInt8('0') || c > UInt8('9')
        unsafe_store!(pos_out, pos)
        unsafe_store!(ok_out, Int32(0))
        return Int32(0)
    end
    value::Int32 = Int32(0)
    while pos < len
        c = obj_at(data, pos)
        if c < UInt8('0') || c > UInt8('9')
            break
        end
        value = value * Int32(10) + Int32(c - UInt8('0'))
        pos = pos + UInt32(1)
    end
    unsafe_store!(pos_out, pos)
    unsafe_store!(ok_out, Int32(1))
    return value * sign
end

function skip_index_tail(data::Ptr{UInt8}, len::UInt32, pos::UInt32)::UInt32
    while pos < len
        c::UInt8 = obj_at(data, pos)
        if c == UInt8(' ') || c == UInt8('\t') || c == UInt8('\n') || c == UInt8('\r')
            return pos
        end
        pos = pos + UInt32(1)
    end
    return pos
end

function obj_index(raw::Int32, vert_count::Int32)::Int32
    if raw < Int32(0)
        return vert_count + raw
    end
    return raw - Int32(1)
end

function store_tri(indices::Ptr{Int32}, tri::Int32, a::Int32, b::Int32, c::Int32)
    # Pointer add is a byte add. elem_ptr multiplies by sizeof(Int32).
    base::Int32 = tri * Int32(3)
    unsafe_store!(elem_ptr(indices, base), a)
    unsafe_store!(elem_ptr(indices, base + Int32(1)), b)
    unsafe_store!(elem_ptr(indices, base + Int32(2)), c)
    return
end

function load_wavefront(path::Ptr{UInt8})
    file::FileBytes = read_file(path)
    if file.ptr == Ptr{UInt8}(C_NULL) || file.len == UInt32(0)
        printf(c"model open failed\n")
        return
    end
    data::Ptr{UInt8} = file.ptr
    len::UInt32 = file.len
    pos_out::Ptr{UInt32} = Ptr{UInt32}(wasm_malloc(UInt32(4)))
    ok_out::Ptr{Int32} = Ptr{Int32}(wasm_malloc(UInt32(4)))
    if pos_out == Ptr{UInt32}(C_NULL) || ok_out == Ptr{Int32}(C_NULL)
        wasm_free(data)
        printf(c"model alloc failed\n")
        return
    end
    vert_count::Int32 = Int32(0)
    tri_count::Int32 = Int32(0)
    pos::UInt32 = UInt32(0)
    while pos < len
        pos = skip_spaces(data, len, pos)
        if pos >= len
            break
        end
        c0::UInt8 = obj_at(data, pos)
        if c0 == UInt8('\n')
            pos = pos + UInt32(1)
        elseif c0 == UInt8('v') && pos + UInt32(1) < len && (obj_at(data, pos + UInt32(1)) == UInt8(' ') || obj_at(data, pos + UInt32(1)) == UInt8('\t'))
            vert_count = vert_count + Int32(1)
            pos = skip_line(data, len, pos)
        elseif c0 == UInt8('f') && pos + UInt32(1) < len && (obj_at(data, pos + UInt32(1)) == UInt8(' ') || obj_at(data, pos + UInt32(1)) == UInt8('\t'))
            pos = pos + UInt32(1)
            n::Int32 = Int32(0)
            while pos < len
                pos = skip_spaces(data, len, pos)
                if pos >= len
                    break
                end
                mark::UInt8 = obj_at(data, pos)
                if mark == UInt8('\n') || mark == UInt8('\r')
                    break
                end
                scan_i32(data, len, pos, pos_out, ok_out)
                if unsafe_load(ok_out) == Int32(0)
                    break
                end
                pos = skip_index_tail(data, len, unsafe_load(pos_out))
                n = n + Int32(1)
            end
            if n >= Int32(3)
                tri_count = tri_count + Int32(1)
            end
            if n >= Int32(4)
                tri_count = tri_count + Int32(1)
            end
            pos = skip_line(data, len, pos)
        else
            pos = skip_line(data, len, pos)
        end
    end
    if vert_count <= Int32(0) || tri_count <= Int32(0)
        wasm_free(data)
        wasm_free(Ptr{UInt8}(pos_out))
        wasm_free(Ptr{UInt8}(ok_out))
        printf(c"model has no triangles\n")
        return
    end
    positions::Ptr{Float64} = Ptr{Float64}(wasm_malloc(UInt32(vert_count) * UInt32(24)))
    indices::Ptr{Int32} = Ptr{Int32}(wasm_malloc(UInt32(tri_count) * UInt32(12)))
    header::Ptr{Mesh} = Ptr{Mesh}(wasm_malloc(UInt32(sizeof(Mesh))))
    if positions == Ptr{Float64}(C_NULL) || indices == Ptr{Int32}(C_NULL) || header == Ptr{Mesh}(C_NULL)
        wasm_free(data)
        wasm_free(Ptr{UInt8}(pos_out))
        wasm_free(Ptr{UInt8}(ok_out))
        printf(c"model alloc failed\n")
        return
    end
    filled_verts::Int32 = Int32(0)
    filled_tris::Int32 = Int32(0)
    pos = UInt32(0)
    while pos < len
        pos = skip_spaces(data, len, pos)
        if pos >= len
            break
        end
        c0 = obj_at(data, pos)
        if c0 == UInt8('\n')
            pos = pos + UInt32(1)
        elseif c0 == UInt8('v') && pos + UInt32(1) < len && (obj_at(data, pos + UInt32(1)) == UInt8(' ') || obj_at(data, pos + UInt32(1)) == UInt8('\t'))
            xcoord::Float64 = scan_f64(data, len, pos + UInt32(1), pos_out)
            ycoord::Float64 = scan_f64(data, len, unsafe_load(pos_out), pos_out)
            zcoord::Float64 = scan_f64(data, len, unsafe_load(pos_out), pos_out)
            base::Int32 = filled_verts * Int32(3)
            unsafe_store!(elem_ptr(positions, base), xcoord)
            unsafe_store!(elem_ptr(positions, base + Int32(1)), ycoord)
            unsafe_store!(elem_ptr(positions, base + Int32(2)), zcoord)
            filled_verts = filled_verts + Int32(1)
            pos = skip_line(data, len, unsafe_load(pos_out))
        elseif c0 == UInt8('f') && pos + UInt32(1) < len && (obj_at(data, pos + UInt32(1)) == UInt8(' ') || obj_at(data, pos + UInt32(1)) == UInt8('\t'))
            pos = pos + UInt32(1)
            n = Int32(0)
            i0::Int32 = Int32(0)
            i1::Int32 = Int32(0)
            i2::Int32 = Int32(0)
            i3::Int32 = Int32(0)
            while pos < len
                pos = skip_spaces(data, len, pos)
                if pos >= len
                    break
                end
                mark = obj_at(data, pos)
                if mark == UInt8('\n') || mark == UInt8('\r')
                    break
                end
                raw_index::Int32 = scan_i32(data, len, pos, pos_out, ok_out)
                if unsafe_load(ok_out) == Int32(0)
                    break
                end
                pos = skip_index_tail(data, len, unsafe_load(pos_out))
                resolved::Int32 = obj_index(raw_index, filled_verts)
                if n == Int32(0)
                    i0 = resolved
                elseif n == Int32(1)
                    i1 = resolved
                elseif n == Int32(2)
                    i2 = resolved
                elseif n == Int32(3)
                    i3 = resolved
                end
                n = n + Int32(1)
            end
            if n >= Int32(3) && i0 >= Int32(0) && i1 >= Int32(0) && i2 >= Int32(0) && i0 < filled_verts && i1 < filled_verts && i2 < filled_verts
                store_tri(indices, filled_tris, i0, i1, i2)
                filled_tris = filled_tris + Int32(1)
            end
            if n >= Int32(4) && i0 >= Int32(0) && i2 >= Int32(0) && i3 >= Int32(0) && i0 < filled_verts && i2 < filled_verts && i3 < filled_verts
                store_tri(indices, filled_tris, i0, i2, i3)
                filled_tris = filled_tris + Int32(1)
            end
            pos = skip_line(data, len, pos)
        else
            pos = skip_line(data, len, pos)
        end
    end
    wasm_free(data)
    wasm_free(Ptr{UInt8}(pos_out))
    wasm_free(Ptr{UInt8}(ok_out))
    minx::Float64 = 1.0e30
    miny::Float64 = 1.0e30
    minz::Float64 = 1.0e30
    maxx::Float64 = -1.0e30
    maxy::Float64 = -1.0e30
    maxz::Float64 = -1.0e30
    vi::Int32 = Int32(0)
    while vi < filled_verts
        b::Int32 = vi * Int32(3)
        x::Float64 = unsafe_load(elem_ptr(positions, b))
        y::Float64 = unsafe_load(elem_ptr(positions, b + Int32(1)))
        z::Float64 = unsafe_load(elem_ptr(positions, b + Int32(2)))
        if x < minx
            minx = x
        end
        if y < miny
            miny = y
        end
        if z < minz
            minz = z
        end
        if x > maxx
            maxx = x
        end
        if y > maxy
            maxy = y
        end
        if z > maxz
            maxz = z
        end
        vi = vi + Int32(1)
    end
    cx::Float64 = (minx + maxx) * 0.5
    cy::Float64 = (miny + maxy) * 0.5
    cz::Float64 = (minz + maxz) * 0.5
    rx::Float64 = (maxx - minx) * 0.5
    ry::Float64 = (maxy - miny) * 0.5
    rz::Float64 = (maxz - minz) * 0.5
    radius::Float64 = rx
    if ry > radius
        radius = ry
    end
    if rz > radius
        radius = rz
    end
    if radius < 0.000001
        radius = 1.0
    end
    unsafe_store!(header, Mesh(positions, indices, filled_verts, filled_tris, cx, cy, cz, radius))
    llvm_set_mesh(header)
    return
end

function yaw_wrap(angle::Float64)::Float64
    turn::Float64 = 6.283185307179586
    half::Float64 = 3.141592653589793
    while angle > half
        angle = angle - turn
    end
    while angle < -half
        angle = angle + turn
    end
    return angle
end

function yaw_sin(angle::Float64)::Float64
    a::Float64 = yaw_wrap(angle)
    a2::Float64 = a * a
    return a * (1.0 - a2 / 6.0 + (a2 * a2) / 120.0 - (a2 * a2 * a2) / 5040.0)
end

function yaw_cos(angle::Float64)::Float64
    a::Float64 = yaw_wrap(angle)
    a2::Float64 = a * a
    return 1.0 - a2 / 2.0 + (a2 * a2) / 24.0 - (a2 * a2 * a2) / 720.0
end

function mesh_sqrt(value::Float64)::Float64
    if value <= 0.0
        return 0.0
    end
    guess::Float64 = value
    if value > 1.0
        guess = value * 0.5
    else
        guess = 1.0
    end
    step::Int32 = Int32(0)
    while step < Int32(8)
        guess = 0.5 * (guess + value / guess)
        step = step + Int32(1)
    end
    return guess
end

function shade_channel(value::Float64)::UInt8
    if value <= 0.0
        return UInt8(0)
    end
    if value >= 255.0
        return UInt8(255)
    end
    return unsafe_trunc(UInt8, value)
end

function clamp_screen(value::Float64)::Int32
    if value > 4000.0
        value = 4000.0
    end
    if value < -4000.0
        value = -4000.0
    end
    return f64_to_i32(value)
end

function vert_x(positions::Ptr{Float64}, index::Int32)::Float64
    return unsafe_load(elem_ptr(positions, index * Int32(3)))
end

function vert_y(positions::Ptr{Float64}, index::Int32)::Float64
    return unsafe_load(elem_ptr(positions, index * Int32(3) + Int32(1)))
end

function vert_z(positions::Ptr{Float64}, index::Int32)::Float64
    return unsafe_load(elem_ptr(positions, index * Int32(3) + Int32(2)))
end

function screen_edge_ok(x0::Int32, y0::Int32, x1::Int32, y1::Int32, limit::Int32)::Int32
    dx::Int32 = x1 - x0
    dy::Int32 = y1 - y0
    if dx < Int32(0)
        dx = -dx
    end
    if dy < Int32(0)
        dy = -dy
    end
    if dx > limit || dy > limit
        return Int32(0)
    end
    return Int32(1)
end

function draw_model_frame(yaw::Float64)
    frame_ptr::Ptr{SoftwareFrame} = llvm_get_software_frame()
    if frame_ptr == Ptr{SoftwareFrame}(C_NULL)
        return
    end
    frame::SoftwareFrame = unsafe_load(frame_ptr)
    if frame.texture == Ptr{SDL_Texture}(C_NULL) || frame.color == Ptr{UInt8}(C_NULL) || frame.depth == Ptr{Float64}(C_NULL)
        return
    end
    clear_software(frame.color, frame.depth, frame.width, frame.height)
    mesh_ptr::Ptr{Mesh} = llvm_get_mesh()
    if mesh_ptr != Ptr{Mesh}(C_NULL)
        mesh::Mesh = unsafe_load(mesh_ptr)
        cos_y::Float64 = yaw_cos(yaw)
        sin_y::Float64 = yaw_sin(yaw)
        # Orthographic framing. Perspective divide was throwing a few verts to the
        # edges and leaving the bust small and off to one side.
        scale::Float64 = Float64(frame.height) * 0.42 / mesh.radius
        half_w::Float64 = Float64(frame.width) * 0.5
        half_h::Float64 = Float64(frame.height) * 0.5
        depth_bias::Float64 = mesh.radius * 2.0
        edge_limit::Int32 = frame.width + frame.height
        lx::Float64 = 0.25
        ly::Float64 = 0.7
        lz::Float64 = 0.67
        llen::Float64 = mesh_sqrt(lx * lx + ly * ly + lz * lz)
        lx = lx / llen
        ly = ly / llen
        lz = lz / llen
        t::Int32 = Int32(0)
        while t < mesh.tri_count
            ib::Int32 = t * Int32(3)
            ia::Int32 = unsafe_load(elem_ptr(mesh.indices, ib))
            ib1::Int32 = unsafe_load(elem_ptr(mesh.indices, ib + Int32(1)))
            ic::Int32 = unsafe_load(elem_ptr(mesh.indices, ib + Int32(2)))
            if ia >= Int32(0) && ib1 >= Int32(0) && ic >= Int32(0) && ia < mesh.vert_count && ib1 < mesh.vert_count && ic < mesh.vert_count
                ax::Float64 = vert_x(mesh.positions, ia) - mesh.cx
                ay::Float64 = vert_y(mesh.positions, ia) - mesh.cy
                az::Float64 = vert_z(mesh.positions, ia) - mesh.cz
                bx::Float64 = vert_x(mesh.positions, ib1) - mesh.cx
                by::Float64 = vert_y(mesh.positions, ib1) - mesh.cy
                bz::Float64 = vert_z(mesh.positions, ib1) - mesh.cz
                px::Float64 = vert_x(mesh.positions, ic) - mesh.cx
                py::Float64 = vert_y(mesh.positions, ic) - mesh.cy
                pz::Float64 = vert_z(mesh.positions, ic) - mesh.cz
                ax2::Float64 = cos_y * ax + sin_y * az
                az2::Float64 = -sin_y * ax + cos_y * az
                bx2::Float64 = cos_y * bx + sin_y * bz
                bz2::Float64 = -sin_y * bx + cos_y * bz
                px2::Float64 = cos_y * px + sin_y * pz
                pz2::Float64 = -sin_y * px + cos_y * pz
                z0::Float64 = az2 + depth_bias
                z1::Float64 = bz2 + depth_bias
                z2::Float64 = pz2 + depth_bias
                sx0::Int32 = clamp_screen(half_w + ax2 * scale)
                sy0::Int32 = clamp_screen(half_h - ay * scale)
                sx1::Int32 = clamp_screen(half_w + bx2 * scale)
                sy1::Int32 = clamp_screen(half_h - by * scale)
                sx2::Int32 = clamp_screen(half_w + px2 * scale)
                sy2::Int32 = clamp_screen(half_h - py * scale)
                if screen_edge_ok(sx0, sy0, sx1, sy1, edge_limit) != Int32(0) && screen_edge_ok(sx1, sy1, sx2, sy2, edge_limit) != Int32(0) && screen_edge_ok(sx2, sy2, sx0, sy0, edge_limit) != Int32(0)
                    ex::Float64 = bx2 - ax2
                    ey::Float64 = by - ay
                    ez::Float64 = bz2 - az2
                    fx::Float64 = px2 - ax2
                    fy::Float64 = py - ay
                    fz::Float64 = pz2 - az2
                    nx::Float64 = ey * fz - ez * fy
                    ny::Float64 = ez * fx - ex * fz
                    nz::Float64 = ex * fy - ey * fx
                    nlen::Float64 = mesh_sqrt(nx * nx + ny * ny + nz * nz)
                    nd::Float64 = 1.0
                    if nlen > 0.000001
                        nd = (nx * lx + ny * ly + nz * lz) / nlen
                        if nd < 0.0
                            nd = -nd
                        end
                    end
                    lit::Float64 = 0.35 + 0.65 * nd
                    draw_triangle_screen(frame.color, frame.depth, frame.width, frame.height, sx0, sy0, z0, sx1, sy1, z1, sx2, sy2, z2, shade_channel(214.0 * lit), shade_channel(164.0 * lit), shade_channel(132.0 * lit))
                end
            end
            t = t + Int32(1)
        end
    end
    pitch::Int32 = frame.width * Int32(4)
    llvm_SDL_UpdateTexture(frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{Cvoid}(frame.color), pitch)
    llvm_SDL_RenderCopy(llvm_get_renderer(), frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{SDL_Rect}(C_NULL))
    return
end
