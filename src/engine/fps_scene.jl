# Procedural first-person bottle range. No OBJ load.

const FPS_BOTTLE_MAX = Int32(8)
const FPS_NEAR = 0.12

struct FpsBottle
    x::Float64
    y::Float64
    z::Float64
    vx::Float64
    vy::Float64
    vz::Float64
    alive::Int32
    resting::Int32
end

struct FpsWorld
    bottles::Ptr{FpsBottle}
    count::Int32
end

function fps_world_slot(do_set::Int32, value::UInt64)::UInt64
    Base.llvmcall(("""
                   @g_fps_world = global i64 0
                   define i64 @main(i32 %do_set, i64 %value) {
                       entry:
                       %set = icmp ne i32 %do_set, 0
                       br i1 %set, label %write, label %read
                       write:
                       store i64 %value, i64* @g_fps_world
                       ret i64 %value
                       read:
                       %v = load i64, i64* @g_fps_world
                       ret i64 %v
                       }
                       """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end

function llvm_set_fps_world(world::Ptr{FpsWorld})
    handle::UInt64 = reinterpret(UInt64, world)
    Base.llvmcall(("""
                   declare i64 @fps_world_slot(i32, i64) nounwind
                   define void @main(i64 %value) {
                       entry:
                       call i64 @fps_world_slot(i32 1, i64 %value)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{UInt64}, handle)
    return
end

function llvm_get_fps_world()::Ptr{FpsWorld}
    handle::UInt64 = Base.llvmcall(("""
                                    declare i64 @fps_world_slot(i32, i64) nounwind
                                    define i64 @main() {
                                        entry:
                                        %r = call i64 @fps_world_slot(i32 0, i64 0)
                                        ret i64 %r
                                        }
                                        """, "main"), UInt64, Tuple{},)
    return reinterpret(Ptr{FpsWorld}, handle)
end

function blank_bottle()::FpsBottle
    return FpsBottle(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Int32(0), Int32(0))
end

function place_bottle(ptr::Ptr{FpsBottle}, index::Int32, x::Float64, y::Float64, z::Float64)
    unsafe_store!(elem_ptr(ptr, index), FpsBottle(x, y, z, 0.0, 0.0, 0.0, Int32(1), Int32(1)))
    return
end

function init_fps_scene()
    bottles::Ptr{FpsBottle} = Ptr{FpsBottle}(wasm_malloc(UInt32(FPS_BOTTLE_MAX) * UInt32(sizeof(FpsBottle))))
    header::Ptr{FpsWorld} = Ptr{FpsWorld}(wasm_malloc(UInt32(sizeof(FpsWorld))))
    if bottles == Ptr{FpsBottle}(C_NULL) || header == Ptr{FpsWorld}(C_NULL)
        return
    end
    i::Int32 = Int32(0)
    while i < FPS_BOTTLE_MAX
        unsafe_store!(elem_ptr(bottles, i), blank_bottle())
        i = i + Int32(1)
    end
    # Bottles sit on barrel tops. Barrel top ≈ 1.05.
    place_bottle(bottles, Int32(0), -2.4, 1.12, 9.0)
    place_bottle(bottles, Int32(1), -2.0, 1.12, 9.0)
    place_bottle(bottles, Int32(2), 0.0, 1.12, 8.2)
    place_bottle(bottles, Int32(3), 0.35, 1.12, 8.2)
    place_bottle(bottles, Int32(4), 2.2, 1.12, 9.4)
    place_bottle(bottles, Int32(5), 2.55, 1.12, 9.4)
    place_bottle(bottles, Int32(6), -0.8, 1.12, 11.5)
    place_bottle(bottles, Int32(7), 0.8, 1.12, 11.5)
    unsafe_store!(header, FpsWorld(bottles, FPS_BOTTLE_MAX))
    llvm_set_fps_world(header)
    llvm_SDL_SetRelativeMouseMode(UInt32(1))
    llvm_SDL_ShowCursor(Int32(0))
    return
end

function fps_clamp_pitch(pitch::Float64)::Float64
    if pitch > 1.4
        return 1.4
    end
    if pitch < -1.4
        return -1.4
    end
    return pitch
end

function project_world(px::Float64, py::Float64, pz::Float64, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, width::Int32, height::Int32, out_x::Ptr{Int32}, out_y::Ptr{Int32}, out_z::Ptr{Float64})::Int32
    dx::Float64 = px - camx
    dy::Float64 = py - camy
    dz::Float64 = pz - camz
    yaw_c::Float64 = yaw_cos(yaw)
    yaw_s::Float64 = yaw_sin(yaw)
    pitch_c::Float64 = yaw_cos(pitch)
    pitch_s::Float64 = yaw_sin(pitch)
    # Camera basis: yaw around Y, then pitch.
    tx::Float64 = dx * yaw_c - dz * yaw_s
    tz::Float64 = dx * yaw_s + dz * yaw_c
    ty::Float64 = dy
    view_x::Float64 = tx
    view_y::Float64 = ty * pitch_c - tz * pitch_s
    view_z::Float64 = ty * pitch_s + tz * pitch_c
    if view_z <= FPS_NEAR
        return Int32(0)
    end
    focal::Float64 = Float64(height) * 0.9
    screen_x::Float64 = Float64(width) * 0.5 + view_x * focal / view_z
    screen_y::Float64 = Float64(height) * 0.5 - view_y * focal / view_z
    if screen_x > 4000.0 || screen_x < -4000.0 || screen_y > 4000.0 || screen_y < -4000.0
        return Int32(0)
    end
    unsafe_store!(out_x, f64_to_i32(screen_x))
    unsafe_store!(out_y, f64_to_i32(screen_y))
    unsafe_store!(out_z, view_z)
    return Int32(1)
end

function draw_tri_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, ax::Float64, ay::Float64, az::Float64, bx::Float64, by::Float64, bz::Float64, cx::Float64, cy::Float64, cz::Float64, red::UInt8, green::UInt8, blue::UInt8, scratch::Ptr{Int32})
    # scratch layout: 6 Int32 screen coords, then 3 Float64 depths (byte offset 32).
    zptr::Ptr{Float64} = Ptr{Float64}(Ptr{UInt8}(scratch) + 32)
    if project_world(ax, ay, az, camx, camy, camz, yaw, pitch, width, height, elem_ptr(scratch, Int32(0)), elem_ptr(scratch, Int32(1)), elem_ptr(zptr, Int32(0))) == Int32(0)
        return
    end
    if project_world(bx, by, bz, camx, camy, camz, yaw, pitch, width, height, elem_ptr(scratch, Int32(2)), elem_ptr(scratch, Int32(3)), elem_ptr(zptr, Int32(1))) == Int32(0)
        return
    end
    if project_world(cx, cy, cz, camx, camy, camz, yaw, pitch, width, height, elem_ptr(scratch, Int32(4)), elem_ptr(scratch, Int32(5)), elem_ptr(zptr, Int32(2))) == Int32(0)
        return
    end
    x0::Int32 = unsafe_load(elem_ptr(scratch, Int32(0)))
    y0::Int32 = unsafe_load(elem_ptr(scratch, Int32(1)))
    x1::Int32 = unsafe_load(elem_ptr(scratch, Int32(2)))
    y1::Int32 = unsafe_load(elem_ptr(scratch, Int32(3)))
    x2::Int32 = unsafe_load(elem_ptr(scratch, Int32(4)))
    y2::Int32 = unsafe_load(elem_ptr(scratch, Int32(5)))
    z0::Float64 = unsafe_load(elem_ptr(zptr, Int32(0)))
    z1::Float64 = unsafe_load(elem_ptr(zptr, Int32(1)))
    z2::Float64 = unsafe_load(elem_ptr(zptr, Int32(2)))
    # Drop huge screen edges (bad projection leftovers).
    lim::Int32 = width + height
    dx::Int32 = x1 - x0
    dy::Int32 = y1 - y0
    if dx < Int32(0)
        dx = -dx
    end
    if dy < Int32(0)
        dy = -dy
    end
    if dx > lim || dy > lim
        return
    end
    # Distance fog.
    fog::Float64 = 1.0 - (z0 + z1 + z2) * 0.02
    if fog < 0.25
        fog = 0.25
    end
    if fog > 1.0
        fog = 1.0
    end
    draw_triangle_screen(color, depth, width, height, x0, y0, z0, x1, y1, z1, x2, y2, z2, shade_channel(Float64(red) * fog), shade_channel(Float64(green) * fog), shade_channel(Float64(blue) * fog))
    return
end

function ring_x(angle::Float64, radius::Float64)::Float64
    return yaw_cos(angle) * radius
end

function ring_z(angle::Float64, radius::Float64)::Float64
    return yaw_sin(angle) * radius
end

function draw_cylinder(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, ox::Float64, oy::Float64, oz::Float64, radius::Float64, tall::Float64, segments::Int32, red::UInt8, green::UInt8, blue::UInt8, scratch::Ptr{Int32})
    i::Int32 = Int32(0)
    while i < segments
        a0::Float64 = Float64(i) * 6.283185307179586 / Float64(segments)
        a1::Float64 = Float64(i + Int32(1)) * 6.283185307179586 / Float64(segments)
        x0::Float64 = ox + ring_x(a0, radius)
        z0::Float64 = oz + ring_z(a0, radius)
        x1::Float64 = ox + ring_x(a1, radius)
        z1::Float64 = oz + ring_z(a1, radius)
        # Side quads as two tris. Shade by facing.
        mid::Float64 = (a0 + a1) * 0.5
        nd::Float64 = yaw_cos(mid - yaw)
        if nd < 0.0
            nd = -nd
        end
        lit::Float64 = 0.35 + 0.65 * nd
        r::UInt8 = shade_channel(Float64(red) * lit)
        g::UInt8 = shade_channel(Float64(green) * lit)
        b::UInt8 = shade_channel(Float64(blue) * lit)
        draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, oy, z0, x1, oy, z1, x1, oy + tall, z1, r, g, b, scratch)
        draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, oy, z0, x1, oy + tall, z1, x0, oy + tall, z0, r, g, b, scratch)
        # Top
        draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, ox, oy + tall, oz, x0, oy + tall, z0, x1, oy + tall, z1, shade_channel(Float64(red) * 0.85), shade_channel(Float64(green) * 0.85), shade_channel(Float64(blue) * 0.85), scratch)
        i = i + Int32(1)
    end
    return
end

function draw_bottle_mesh(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, ox::Float64, oy::Float64, oz::Float64, scratch::Ptr{Int32})
    # Green glass body + neck.
    draw_cylinder(color, depth, width, height, camx, camy, camz, yaw, pitch, ox, oy, oz, 0.11, 0.38, Int32(8), UInt8(72), UInt8(140), UInt8(78), scratch)
    draw_cylinder(color, depth, width, height, camx, camy, camz, yaw, pitch, ox, oy + 0.38, oz, 0.05, 0.22, Int32(6), UInt8(96), UInt8(168), UInt8(100), scratch)
    return
end

function draw_barrel(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, ox::Float64, oz::Float64, scratch::Ptr{Int32})
    draw_cylinder(color, depth, width, height, camx, camy, camz, yaw, pitch, ox, 0.0, oz, 0.55, 1.05, Int32(10), UInt8(118), UInt8(74), UInt8(36), scratch)
    # Dark hoop bands.
    draw_cylinder(color, depth, width, height, camx, camy, camz, yaw, pitch, ox, 0.28, oz, 0.57, 0.06, Int32(10), UInt8(48), UInt8(36), UInt8(28), scratch)
    draw_cylinder(color, depth, width, height, camx, camy, camz, yaw, pitch, ox, 0.72, oz, 0.57, 0.06, Int32(10), UInt8(48), UInt8(36), UInt8(28), scratch)
    return
end

function draw_floor(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, scratch::Ptr{Int32})
    gx::Int32 = Int32(-6)
    while gx < Int32(6)
        gz::Int32 = Int32(2)
        while gz < Int32(16)
            x0::Float64 = Float64(gx)
            z0::Float64 = Float64(gz)
            x1::Float64 = x0 + 1.0
            z1::Float64 = z0 + 1.0
            checker::Int32 = (gx + gz) & Int32(1)
            r::UInt8 = UInt8(54)
            g::UInt8 = UInt8(58)
            b::UInt8 = UInt8(64)
            if checker == Int32(0)
                r = UInt8(72)
                g = UInt8(68)
                b = UInt8(58)
            end
            draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, 0.0, z0, x1, 0.0, z0, x1, 0.0, z1, r, g, b, scratch)
            draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, 0.0, z0, x1, 0.0, z1, x0, 0.0, z1, r, g, b, scratch)
            gz = gz + Int32(1)
        end
        gx = gx + Int32(1)
    end
    return
end

function draw_backstop(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, scratch::Ptr{Int32})
    # Wooden fence wall at the far end.
    draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, -5.0, 0.0, 14.5, 5.0, 0.0, 14.5, 5.0, 2.4, 14.5, UInt8(92), UInt8(58), UInt8(32), scratch)
    draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, -5.0, 0.0, 14.5, 5.0, 2.4, 14.5, -5.0, 2.4, 14.5, UInt8(84), UInt8(52), UInt8(28), scratch)
    return
end

function plot_hud(color::Ptr{UInt8}, width::Int32, height::Int32, x::Int32, y::Int32, red::UInt8, green::UInt8, blue::UInt8)
    if x < Int32(0) || y < Int32(0) || x >= width || y >= height
        return
    end
    index::Int32 = y * width + x
    pixel::Ptr{UInt8} = color + (Int(index) * 4)
    unsafe_store!(pixel, red)
    unsafe_store!(pixel + 1, green)
    unsafe_store!(pixel + 2, blue)
    unsafe_store!(pixel + 3, UInt8(255))
    return
end

function draw_crosshair(color::Ptr{UInt8}, width::Int32, height::Int32)
    cx::Int32 = width / Int32(2)
    cy::Int32 = height / Int32(2)
    i::Int32 = Int32(-5)
    while i <= Int32(5)
        if i < Int32(-1) || i > Int32(1)
            plot_hud(color, width, height, cx + i, cy, UInt8(236), UInt8(228), UInt8(196))
            plot_hud(color, width, height, cx, cy + i, UInt8(236), UInt8(228), UInt8(196))
        end
        i = i + Int32(1)
    end
    return
end

function update_fps_bottles(dt::Float64)
    world_ptr::Ptr{FpsWorld} = llvm_get_fps_world()
    if world_ptr == Ptr{FpsWorld}(C_NULL)
        return
    end
    world::FpsWorld = unsafe_load(world_ptr)
    i::Int32 = Int32(0)
    while i < world.count
        b::FpsBottle = unsafe_load(elem_ptr(world.bottles, i))
        if b.alive != Int32(0) && b.resting == Int32(0)
            vy::Float64 = b.vy - 9.5 * dt
            x::Float64 = b.x + b.vx * dt
            y::Float64 = b.y + vy * dt
            z::Float64 = b.z + b.vz * dt
            vx::Float64 = b.vx * 0.99
            vz::Float64 = b.vz * 0.99
            resting::Int32 = Int32(0)
            if y <= 0.05
                y = 0.05
                vy = 0.0
                vx = vx * 0.5
                vz = vz * 0.5
                if vx * vx + vz * vz < 0.02
                    resting = Int32(1)
                    vx = 0.0
                    vz = 0.0
                end
            end
            unsafe_store!(elem_ptr(world.bottles, i), FpsBottle(x, y, z, vx, vy, vz, Int32(1), resting))
        end
        i = i + Int32(1)
    end
    return
end

function try_shoot_bottles(camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64)
    world_ptr::Ptr{FpsWorld} = llvm_get_fps_world()
    if world_ptr == Ptr{FpsWorld}(C_NULL)
        return
    end
    world::FpsWorld = unsafe_load(world_ptr)
    cy::Float64 = yaw_cos(yaw)
    sy::Float64 = yaw_sin(yaw)
    cp::Float64 = yaw_cos(pitch)
    sp::Float64 = yaw_sin(pitch)
    # Forward in world after yaw then pitch matching project_world.
    # view: x right, y up, z forward. Inverse: walk along +view_z.
    fx::Float64 = sy * cp
    fy::Float64 = sp
    fz::Float64 = cy * cp
    best_t::Float64 = 40.0
    best::Int32 = Int32(-1)
    i::Int32 = Int32(0)
    while i < world.count
        b::FpsBottle = unsafe_load(elem_ptr(world.bottles, i))
        if b.alive != Int32(0)
            # Sphere at bottle center.
            bx::Float64 = b.x - camx
            by::Float64 = b.y + 0.25 - camy
            bz::Float64 = b.z - camz
            t::Float64 = bx * fx + by * fy + bz * fz
            if t > 0.2 && t < best_t
                px::Float64 = camx + fx * t
                py::Float64 = camy + fy * t
                pz::Float64 = camz + fz * t
                dx::Float64 = b.x - px
                dy::Float64 = (b.y + 0.25) - py
                dz::Float64 = b.z - pz
                if dx * dx + dy * dy + dz * dz <= 0.22 * 0.22
                    best_t = t
                    best = i
                end
            end
        end
        i = i + Int32(1)
    end
    if best >= Int32(0)
        b = unsafe_load(elem_ptr(world.bottles, best))
        unsafe_store!(elem_ptr(world.bottles, best), FpsBottle(b.x, b.y, b.z, fx * 7.5, fy * 7.5 + 2.8, fz * 7.5, Int32(1), Int32(0)))
    end
    return
end

function draw_fps_scene(dt::Float64)
    frame_ptr::Ptr{SoftwareFrame} = llvm_get_software_frame()
    if frame_ptr == Ptr{SoftwareFrame}(C_NULL)
        return
    end
    frame::SoftwareFrame = unsafe_load(frame_ptr)
    if frame.texture == Ptr{SDL_Texture}(C_NULL) || frame.color == Ptr{UInt8}(C_NULL) || frame.depth == Ptr{Float64}(C_NULL)
        return
    end
    # Warm dusk clear instead of cold blue.
    count::Int32 = frame.width * frame.height
    i::Int32 = Int32(0)
    while i < count
        pixel::Ptr{UInt8} = frame.color + (Int(i) * 4)
        unsafe_store!(pixel, UInt8(28))
        unsafe_store!(pixel + 1, UInt8(24))
        unsafe_store!(pixel + 2, UInt8(32))
        unsafe_store!(pixel + 3, UInt8(255))
        unsafe_store!(elem_ptr(frame.depth, i), 0.0)
        i = i + Int32(1)
    end

    camx::Float64 = llvm_game_cam_x()
    camy::Float64 = llvm_game_cam_y()
    camz::Float64 = llvm_game_cam_z()
    yaw::Float64 = llvm_game_cam_yaw()
    pitch::Float64 = fps_clamp_pitch(llvm_game_cam_pitch())

    if llvm_game_consume_shot() != Int32(0)
        try_shoot_bottles(camx, camy, camz, yaw, pitch)
    end
    update_fps_bottles(dt)

    scratch::Ptr{Int32} = Ptr{Int32}(wasm_malloc(UInt32(64)))
    if scratch == Ptr{Int32}(C_NULL)
        return
    end

    draw_floor(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, scratch)
    draw_backstop(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, scratch)
    draw_barrel(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, -2.2, 9.0, scratch)
    draw_barrel(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, 0.15, 8.2, scratch)
    draw_barrel(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, 2.35, 9.4, scratch)
    draw_barrel(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, 0.0, 11.5, scratch)

    world_ptr::Ptr{FpsWorld} = llvm_get_fps_world()
    if world_ptr != Ptr{FpsWorld}(C_NULL)
        world::FpsWorld = unsafe_load(world_ptr)
        bi::Int32 = Int32(0)
        while bi < world.count
            bottle::FpsBottle = unsafe_load(elem_ptr(world.bottles, bi))
            if bottle.alive != Int32(0)
                draw_bottle_mesh(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, bottle.x, bottle.y, bottle.z, scratch)
            end
            bi = bi + Int32(1)
        end
    end

    draw_crosshair(frame.color, frame.width, frame.height)
    wasm_free(Ptr{UInt8}(scratch))

    pitch_bytes::Int32 = frame.width * Int32(4)
    llvm_SDL_UpdateTexture(frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{Cvoid}(frame.color), pitch_bytes)
    llvm_SDL_RenderCopy(llvm_get_renderer(), frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{SDL_Rect}(C_NULL))
    return
end
