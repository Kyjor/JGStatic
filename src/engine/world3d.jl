# Generic 3D world the C game fills each frame: draws, AABBs, hit spheres, HUD.
# No mission or combat rules live here.

const DRAW_MAX = Int32(128)
const AABB_MAX = Int32(112)
const SPHERE_MAX = Int32(16)
const HUD_MAX = Int32(64)
const WORLD_NEAR = 0.12

const KIND_BOX = Int32(1)
const KIND_CYL = Int32(2)
const KIND_QUAD = Int32(3)
const KIND_GRID = Int32(4)
const KIND_VIEW = Int32(5)

const HUD_BAR = Int32(1)
const HUD_DIGITS = Int32(2)
const HUD_TEXT = Int32(3)
const HUD_CROSS = Int32(4)
const HUD_PANEL = Int32(5)

struct DrawItem
    kind::Int32
    x::Float64
    y::Float64
    z::Float64
    sx::Float64
    sy::Float64
    sz::Float64
    segs::Int32
    cr::Int32
    cg::Int32
    cb::Int32
    x1::Float64
    y1::Float64
    z1::Float64
    x2::Float64
    y2::Float64
    z2::Float64
    x3::Float64
    y3::Float64
    z3::Float64
end

struct Aabb
    x::Float64
    y::Float64
    z::Float64
    sx::Float64
    sy::Float64
    sz::Float64
end

struct HitSphere
    id::Int32
    x::Float64
    y::Float64
    z::Float64
    radius::Float64
end

struct HudItem
    kind::Int32
    x::Int32
    y::Int32
    w::Int32
    h::Int32
    value::Int32
    scale::Int32
    cr::Int32
    cg::Int32
    cb::Int32
    cr2::Int32
    cg2::Int32
    cb2::Int32
    text::Ptr{UInt8}
end

struct World3D
    draws::Ptr{DrawItem}
    draw_count::Int32
    aabbs::Ptr{Aabb}
    aabb_count::Int32
    spheres::Ptr{HitSphere}
    sphere_count::Int32
    huds::Ptr{HudItem}
    hud_count::Int32
    snd_shot::Ptr{Mix_Chunk}
    snd_death::Ptr{Mix_Chunk}
    snd_jump::Ptr{Mix_Chunk}
    music::Ptr{Cvoid}
    flash_r::Int32
    flash_g::Int32
    flash_b::Int32
    flash_a::Int32
    clear_r::Int32
    clear_g::Int32
    clear_b::Int32
end

function world3d_slot(do_set::Int32, value::UInt64)::UInt64
    Base.llvmcall(("""
                   @g_world3d = global i64 0
                   define i64 @main(i32 %do_set, i64 %value) {
                       entry:
                       %set = icmp ne i32 %do_set, 0
                       br i1 %set, label %write, label %read
                       write:
                       store i64 %value, i64* @g_world3d
                       ret i64 %value
                       read:
                       %v = load i64, i64* @g_world3d
                       ret i64 %v
                       }
                       """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end

function llvm_set_world3d(world::Ptr{World3D})
    handle::UInt64 = reinterpret(UInt64, world)
    Base.llvmcall(("""
                   declare i64 @world3d_slot(i32, i64) nounwind
                   define void @main(i64 %value) {
                       entry:
                       call i64 @world3d_slot(i32 1, i64 %value)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{UInt64}, handle)
    return
end

function llvm_get_world3d()::Ptr{World3D}
    handle::UInt64 = Base.llvmcall(("""
                                    declare i64 @world3d_slot(i32, i64) nounwind
                                    define i64 @main() {
                                        entry:
                                        %r = call i64 @world3d_slot(i32 0, i64 0)
                                        ret i64 %r
                                        }
                                        """, "main"), UInt64, Tuple{},)
    return reinterpret(Ptr{World3D}, handle)
end

function llvm_mix_load_mus(file::Ptr{UInt8})::Ptr{Cvoid}
    return Base.llvmcall(("""
                          declare i8* @Mix_LoadMUS(i8*) nounwind
                          define i8* @main(i8* %file) {
                              entry:
                              %r = call i8* @Mix_LoadMUS(i8* %file)
                              ret i8* %r
                              }
                              """, "main"), Ptr{Cvoid}, Tuple{Ptr{UInt8}}, file)
end

function llvm_mix_play_music(music::Ptr{Cvoid}, loops::Int32)::Int32
    return Base.llvmcall(("""
                          declare i32 @Mix_PlayMusic(i8*, i32) nounwind
                          define i32 @main(i8* %music, i32 %loops) {
                              entry:
                              %r = call i32 @Mix_PlayMusic(i8* %music, i32 %loops)
                              ret i32 %r
                              }
                              """, "main"), Int32, Tuple{Ptr{Cvoid}, Int32}, music, loops)
end

function blank_draw()::DrawItem
    return DrawItem(Int32(0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Int32(0), Int32(0), Int32(0), Int32(0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function blank_aabb()::Aabb
    return Aabb(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function blank_sphere()::HitSphere
    return HitSphere(Int32(0), 0.0, 0.0, 0.0, 0.0)
end

function blank_hud()::HudItem
    return HudItem(Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Ptr{UInt8}(C_NULL))
end

function store_world(world::World3D)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    unsafe_store!(ptr, world)
    return
end

function copy_world(src::World3D, draw_count::Int32, aabb_count::Int32, sphere_count::Int32, hud_count::Int32, flash_r::Int32, flash_g::Int32, flash_b::Int32, flash_a::Int32, clear_r::Int32, clear_g::Int32, clear_b::Int32)::World3D
    return World3D(src.draws, draw_count, src.aabbs, aabb_count, src.spheres, sphere_count, src.huds, hud_count, src.snd_shot, src.snd_death, src.snd_jump, src.music, flash_r, flash_g, flash_b, flash_a, clear_r, clear_g, clear_b)
end

function load_named_wav(file::WallocString)::Ptr{Mix_Chunk}
    name::Ptr{UInt8} = str_ptr(file)
    base::Ptr{UInt8} = str_ptr(w".")
    full::Ptr{UInt8} = malloc_joined_path(base, name, ASSETS_SOUNDS_INFIX)
    wasm_free(name)
    wasm_free(base)
    chunk::Ptr{Mix_Chunk} = Ptr{Mix_Chunk}(C_NULL)
    if full != Ptr{UInt8}(C_NULL)
        chunk = llvm_Mix_LoadWAV(full)
        wasm_free(full)
    end
    return chunk
end

function load_named_mus(file::WallocString)::Ptr{Cvoid}
    name::Ptr{UInt8} = str_ptr(file)
    base::Ptr{UInt8} = str_ptr(w".")
    full::Ptr{UInt8} = malloc_joined_path(base, name, ASSETS_SOUNDS_INFIX)
    wasm_free(name)
    wasm_free(base)
    music::Ptr{Cvoid} = Ptr{Cvoid}(C_NULL)
    if full != Ptr{UInt8}(C_NULL)
        music = llvm_mix_load_mus(full)
        wasm_free(full)
    end
    return music
end

function init_world3d()
    draws::Ptr{DrawItem} = Ptr{DrawItem}(wasm_malloc(UInt32(DRAW_MAX) * UInt32(sizeof(DrawItem))))
    aabbs::Ptr{Aabb} = Ptr{Aabb}(wasm_malloc(UInt32(AABB_MAX) * UInt32(sizeof(Aabb))))
    spheres::Ptr{HitSphere} = Ptr{HitSphere}(wasm_malloc(UInt32(SPHERE_MAX) * UInt32(sizeof(HitSphere))))
    huds::Ptr{HudItem} = Ptr{HudItem}(wasm_malloc(UInt32(HUD_MAX) * UInt32(sizeof(HudItem))))
    header::Ptr{World3D} = Ptr{World3D}(wasm_malloc(UInt32(sizeof(World3D))))
    if draws == Ptr{DrawItem}(C_NULL) || aabbs == Ptr{Aabb}(C_NULL) || spheres == Ptr{HitSphere}(C_NULL) || huds == Ptr{HudItem}(C_NULL) || header == Ptr{World3D}(C_NULL)
        printf(c"world3d alloc failed\n")
        return
    end
    i::Int32 = Int32(0)
    while i < DRAW_MAX
        unsafe_store!(elem_ptr(draws, i), blank_draw())
        i = i + Int32(1)
    end
    i = Int32(0)
    while i < AABB_MAX
        unsafe_store!(elem_ptr(aabbs, i), blank_aabb())
        i = i + Int32(1)
    end
    i = Int32(0)
    while i < SPHERE_MAX
        unsafe_store!(elem_ptr(spheres, i), blank_sphere())
        i = i + Int32(1)
    end
    i = Int32(0)
    while i < HUD_MAX
        unsafe_store!(elem_ptr(huds, i), blank_hud())
        i = i + Int32(1)
    end
    shot::Ptr{Mix_Chunk} = load_named_wav(w"LaserShoot.wav")
    death::Ptr{Mix_Chunk} = load_named_wav(w"Death.wav")
    jump::Ptr{Mix_Chunk} = load_named_wav(w"Jump.wav")
    music::Ptr{Cvoid} = load_named_mus(w"Music.mp3")
    unsafe_store!(header, World3D(draws, Int32(0), aabbs, Int32(0), spheres, Int32(0), huds, Int32(0), shot, death, jump, music, Int32(0), Int32(0), Int32(0), Int32(0), Int32(22), Int32(18), Int32(32)))
    llvm_set_world3d(header)
    if music != Ptr{Cvoid}(C_NULL)
        llvm_mix_play_music(music, Int32(-1))
    end
    llvm_SDL_SetRelativeMouseMode(UInt32(0))
    llvm_SDL_ShowCursor(Int32(1))
    return
end

function jg3_begin_frame()
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    unsafe_store!(ptr, copy_world(world, Int32(0), world.aabb_count, Int32(0), Int32(0), world.flash_r, world.flash_g, world.flash_b, world.flash_a, world.clear_r, world.clear_g, world.clear_b))
    return
end

function jg3_set_clear(r::Int32, g::Int32, b::Int32)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    unsafe_store!(ptr, copy_world(world, world.draw_count, world.aabb_count, world.sphere_count, world.hud_count, world.flash_r, world.flash_g, world.flash_b, world.flash_a, r, g, b))
    return
end

function push_draw(item::DrawItem)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    if world.draws == Ptr{DrawItem}(C_NULL) || world.draw_count >= DRAW_MAX
        return
    end
    unsafe_store!(elem_ptr(world.draws, world.draw_count), item)
    unsafe_store!(ptr, copy_world(world, world.draw_count + Int32(1), world.aabb_count, world.sphere_count, world.hud_count, world.flash_r, world.flash_g, world.flash_b, world.flash_a, world.clear_r, world.clear_g, world.clear_b))
    return
end

function jg3_draw_box(x::Float64, y::Float64, z::Float64, sx::Float64, sy::Float64, sz::Float64, r::Int32, g::Int32, b::Int32)
    push_draw(DrawItem(KIND_BOX, x, y, z, sx, sy, sz, Int32(0), r, g, b, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0))
    return
end

function jg3_draw_cylinder(x::Float64, y::Float64, z::Float64, radius::Float64, height::Float64, segs::Int32, r::Int32, g::Int32, b::Int32)
    item::DrawItem = DrawItem(KIND_CYL, x, y, z, radius, height, 0.0, segs, r, g, b, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    push_draw(item)
    return
end

function jg3_draw_quad(x0::Float64, y0::Float64, z0::Float64, x1::Float64, y1::Float64, z1::Float64, x2::Float64, y2::Float64, z2::Float64, x3::Float64, y3::Float64, z3::Float64, r::Int32, g::Int32, b::Int32)
    item::DrawItem = DrawItem(KIND_QUAD, x0, y0, z0, 0.0, 0.0, 0.0, Int32(0), r, g, b, x1, y1, z1, x2, y2, z2, x3, y3, z3)
    push_draw(item)
    return
end

function jg3_draw_grid(x::Float64, y::Float64, z::Float64, sx::Float64, sz::Float64, step::Float64, r::Int32, g::Int32, b::Int32)
    item::DrawItem = DrawItem(KIND_GRID, x, y, z, sx, step, sz, Int32(0), r, g, b, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    push_draw(item)
    return
end

# Box aligned to a camera basis: sx along right, sy along up, sz along forward.
function jg3_draw_viewbox(x::Float64, y::Float64, z::Float64, sx::Float64, sy::Float64, sz::Float64, rx::Float64, ry::Float64, rz::Float64, ux::Float64, uy::Float64, uz::Float64, fx::Float64, fy::Float64, fz::Float64, r::Int32, g::Int32, b::Int32)
    item::DrawItem = DrawItem(KIND_VIEW, x, y, z, sx, sy, sz, Int32(0), r, g, b, rx, ry, rz, ux, uy, uz, fx, fy, fz)
    push_draw(item)
    return
end

function jg3_clear_colliders()
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    unsafe_store!(ptr, copy_world(world, world.draw_count, Int32(0), world.sphere_count, world.hud_count, world.flash_r, world.flash_g, world.flash_b, world.flash_a, world.clear_r, world.clear_g, world.clear_b))
    return
end

function jg3_add_aabb(x::Float64, y::Float64, z::Float64, sx::Float64, sy::Float64, sz::Float64)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    if world.aabbs == Ptr{Aabb}(C_NULL) || world.aabb_count >= AABB_MAX
        return
    end
    if sx <= 0.0 || sy <= 0.0 || sz <= 0.0
        return
    end
    unsafe_store!(elem_ptr(world.aabbs, world.aabb_count), Aabb(x, y, z, sx, sy, sz))
    unsafe_store!(ptr, copy_world(world, world.draw_count, world.aabb_count + Int32(1), world.sphere_count, world.hud_count, world.flash_r, world.flash_g, world.flash_b, world.flash_a, world.clear_r, world.clear_g, world.clear_b))
    return
end

function aabb_hits(px::Float64, py::Float64, pz::Float64, radius::Float64, height::Float64, box::Aabb)::Int32
    minx::Float64 = px - radius
    maxx::Float64 = px + radius
    miny::Float64 = py
    maxy::Float64 = py + height
    minz::Float64 = pz - radius
    maxz::Float64 = pz + radius
    if maxx <= box.x || minx >= box.x + box.sx
        return Int32(0)
    end
    if maxy <= box.y || miny >= box.y + box.sy
        return Int32(0)
    end
    if maxz <= box.z || minz >= box.z + box.sz
        return Int32(0)
    end
    return Int32(1)
end

function solid_at(world::World3D, px::Float64, py::Float64, pz::Float64, radius::Float64, height::Float64)::Int32
    i::Int32 = Int32(0)
    while i < world.aabb_count
        box::Aabb = unsafe_load(elem_ptr(world.aabbs, i))
        if aabb_hits(px, py, pz, radius, height, box) != Int32(0)
            return Int32(1)
        end
        i = i + Int32(1)
    end
    return Int32(0)
end

function jg3_move_collide(px::Float64, py::Float64, pz::Float64, dx::Float64, dy::Float64, dz::Float64, radius::Float64, height::Float64, out_x::Ptr{Float64}, out_y::Ptr{Float64}, out_z::Ptr{Float64})
    ptr::Ptr{World3D} = llvm_get_world3d()
    nx::Float64 = px + dx
    ny::Float64 = py + dy
    nz::Float64 = pz + dz
    if ptr != Ptr{World3D}(C_NULL)
        world::World3D = unsafe_load(ptr)
        if solid_at(world, nx, py, pz, radius, height) != Int32(0)
            nx = px
        end
        if solid_at(world, nx, py, nz, radius, height) != Int32(0)
            nz = pz
        end
        if solid_at(world, nx, ny, nz, radius, height) != Int32(0)
            ny = py
        end
    end
    if out_x != Ptr{Float64}(C_NULL)
        unsafe_store!(out_x, nx)
    end
    if out_y != Ptr{Float64}(C_NULL)
        unsafe_store!(out_y, ny)
    end
    if out_z != Ptr{Float64}(C_NULL)
        unsafe_store!(out_z, nz)
    end
    return
end

function jg3_add_hit_sphere(id::Int32, x::Float64, y::Float64, z::Float64, radius::Float64)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    if world.spheres == Ptr{HitSphere}(C_NULL) || world.sphere_count >= SPHERE_MAX
        return
    end
    if radius <= 0.0
        return
    end
    unsafe_store!(elem_ptr(world.spheres, world.sphere_count), HitSphere(id, x, y, z, radius))
    unsafe_store!(ptr, copy_world(world, world.draw_count, world.aabb_count, world.sphere_count + Int32(1), world.hud_count, world.flash_r, world.flash_g, world.flash_b, world.flash_a, world.clear_r, world.clear_g, world.clear_b))
    return
end

function ray_aabb_t(ox::Float64, oy::Float64, oz::Float64, dx::Float64, dy::Float64, dz::Float64, box::Aabb, max_t::Float64)::Float64
    tmin::Float64 = 0.0
    tmax::Float64 = max_t
    # Slab test is inlined per axis so the running interval stays in locals.
    if dx < 0.0000001 && dx > -0.0000001
        if ox < box.x || ox > box.x + box.sx
            return -1.0
        end
    else
        invx::Float64 = 1.0 / dx
        x1::Float64 = (box.x - ox) * invx
        x2::Float64 = (box.x + box.sx - ox) * invx
        if x1 > x2
            swapx::Float64 = x1
            x1 = x2
            x2 = swapx
        end
        if x1 > tmin
            tmin = x1
        end
        if x2 < tmax
            tmax = x2
        end
        if tmin > tmax
            return -1.0
        end
    end
    if dy < 0.0000001 && dy > -0.0000001
        if oy < box.y || oy > box.y + box.sy
            return -1.0
        end
    else
        invy::Float64 = 1.0 / dy
        y1::Float64 = (box.y - oy) * invy
        y2::Float64 = (box.y + box.sy - oy) * invy
        if y1 > y2
            swapy::Float64 = y1
            y1 = y2
            y2 = swapy
        end
        if y1 > tmin
            tmin = y1
        end
        if y2 < tmax
            tmax = y2
        end
        if tmin > tmax
            return -1.0
        end
    end
    if dz < 0.0000001 && dz > -0.0000001
        if oz < box.z || oz > box.z + box.sz
            return -1.0
        end
    else
        invz::Float64 = 1.0 / dz
        z1::Float64 = (box.z - oz) * invz
        z2::Float64 = (box.z + box.sz - oz) * invz
        if z1 > z2
            swapz::Float64 = z1
            z1 = z2
            z2 = swapz
        end
        if z1 > tmin
            tmin = z1
        end
        if z2 < tmax
            tmax = z2
        end
        if tmin > tmax
            return -1.0
        end
    end
    if tmin < 0.0
        tmin = 0.0
    end
    if tmin > max_t
        return -1.0
    end
    return tmin
end

function ray_sphere_t(ox::Float64, oy::Float64, oz::Float64, dx::Float64, dy::Float64, dz::Float64, cx::Float64, cy::Float64, cz::Float64, radius::Float64, max_t::Float64)::Float64
    lx::Float64 = cx - ox
    ly::Float64 = cy - oy
    lz::Float64 = cz - oz
    tca::Float64 = lx * dx + ly * dy + lz * dz
    if tca < 0.0
        return -1.0
    end
    d2::Float64 = lx * lx + ly * ly + lz * lz - tca * tca
    r2::Float64 = radius * radius
    if d2 > r2
        return -1.0
    end
    thc::Float64 = mesh_sqrt(r2 - d2)
    t0::Float64 = tca - thc
    if t0 < 0.0
        t0 = tca + thc
    end
    if t0 < 0.0 || t0 > max_t
        return -1.0
    end
    return t0
end

function jg3_raycast(ox::Float64, oy::Float64, oz::Float64, dx::Float64, dy::Float64, dz::Float64, max_t::Float64, hit_mask::Int32, ignore_id::Int32, out_t::Ptr{Float64})::Int32
    len::Float64 = mesh_sqrt(dx * dx + dy * dy + dz * dz)
    if len < 0.0000001 || max_t <= 0.0
        return Int32(-1)
    end
    dx = dx / len
    dy = dy / len
    dz = dz / len
    ptr::Ptr{World3D} = llvm_get_world3d()
    best_t::Float64 = max_t + 1.0
    best_id::Int32 = Int32(-1)
    if ptr != Ptr{World3D}(C_NULL)
        world::World3D = unsafe_load(ptr)
        if (hit_mask & Int32(1)) != Int32(0)
            i::Int32 = Int32(0)
            while i < world.aabb_count
                box::Aabb = unsafe_load(elem_ptr(world.aabbs, i))
                t::Float64 = ray_aabb_t(ox, oy, oz, dx, dy, dz, box, max_t)
                if t >= 0.0 && t < best_t
                    best_t = t
                    best_id = Int32(-2)
                end
                i = i + Int32(1)
            end
        end
        if (hit_mask & Int32(2)) != Int32(0)
            s::Int32 = Int32(0)
            while s < world.sphere_count
                sphere::HitSphere = unsafe_load(elem_ptr(world.spheres, s))
                if sphere.id != ignore_id
                    ts::Float64 = ray_sphere_t(ox, oy, oz, dx, dy, dz, sphere.x, sphere.y, sphere.z, sphere.radius, max_t)
                    if ts >= 0.0 && ts < best_t
                        best_t = ts
                        best_id = sphere.id
                    end
                end
                s = s + Int32(1)
            end
        end
    end
    if best_id == Int32(-1)
        return Int32(-1)
    end
    if out_t != Ptr{Float64}(C_NULL)
        unsafe_store!(out_t, best_t)
    end
    return best_id
end

function push_hud(item::HudItem)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    if world.huds == Ptr{HudItem}(C_NULL) || world.hud_count >= HUD_MAX
        return
    end
    unsafe_store!(elem_ptr(world.huds, world.hud_count), item)
    unsafe_store!(ptr, copy_world(world, world.draw_count, world.aabb_count, world.sphere_count, world.hud_count + Int32(1), world.flash_r, world.flash_g, world.flash_b, world.flash_a, world.clear_r, world.clear_g, world.clear_b))
    return
end

function jg3_hud_bar(x::Int32, y::Int32, w::Int32, h::Int32, filled::Int32, r::Int32, g::Int32, b::Int32, br::Int32, bg::Int32, bb::Int32)
    push_hud(HudItem(HUD_BAR, x, y, w, h, filled, Int32(1), r, g, b, br, bg, bb, Ptr{UInt8}(C_NULL)))
    return
end

function jg3_hud_digits(x::Int32, y::Int32, value::Int32, min_digits::Int32, scale::Int32, r::Int32, g::Int32, b::Int32)
    push_hud(HudItem(HUD_DIGITS, x, y, Int32(0), Int32(0), value, scale, r, g, b, min_digits, Int32(0), Int32(0), Ptr{UInt8}(C_NULL)))
    return
end

function jg3_hud_text(x::Int32, y::Int32, scale::Int32, r::Int32, g::Int32, b::Int32, text::Ptr{UInt8})
    push_hud(HudItem(HUD_TEXT, x, y, Int32(0), Int32(0), Int32(0), scale, r, g, b, Int32(0), Int32(0), Int32(0), text))
    return
end

function jg3_crosshair(gap::Int32, r::Int32, g::Int32, b::Int32)
    push_hud(HudItem(HUD_CROSS, Int32(0), Int32(0), Int32(0), Int32(0), gap, Int32(1), r, g, b, Int32(0), Int32(0), Int32(0), Ptr{UInt8}(C_NULL)))
    return
end

function jg3_hud_panel(x::Int32, y::Int32, w::Int32, h::Int32, r::Int32, g::Int32, b::Int32, br::Int32, bg::Int32, bb::Int32)
    push_hud(HudItem(HUD_PANEL, x, y, w, h, Int32(0), Int32(1), r, g, b, br, bg, bb, Ptr{UInt8}(C_NULL)))
    return
end

function jg3_key(scancode::Int32)::Int32
    state::Ptr{UInt8} = Base.llvmcall(("""
                   declare i8* @SDL_GetKeyboardState(i32*) nounwind
                   define i8* @main() {
                       entry:
                       %p = call i8* @SDL_GetKeyboardState(i32* null)
                       ret i8* %p
                       }
                       """, "main"), Ptr{UInt8}, Tuple{},)
    if state == Ptr{UInt8}(C_NULL) || scancode < Int32(0) || scancode >= Int32(512)
        return Int32(0)
    end
    if unsafe_load(state + Int(scancode)) == UInt8(0)
        return Int32(0)
    end
    return Int32(1)
end

function jg3_mouse_look(on::Int32)
    if on != Int32(0)
        llvm_SDL_SetRelativeMouseMode(UInt32(1))
        llvm_SDL_ShowCursor(Int32(0))
    else
        llvm_SDL_SetRelativeMouseMode(UInt32(0))
        llvm_SDL_ShowCursor(Int32(1))
    end
    return
end

function jg3_screen_flash(r::Int32, g::Int32, b::Int32, amount::Int32)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    if amount < Int32(0)
        amount = Int32(0)
    end
    if amount > Int32(255)
        amount = Int32(255)
    end
    world::World3D = unsafe_load(ptr)
    unsafe_store!(ptr, copy_world(world, world.draw_count, world.aabb_count, world.sphere_count, world.hud_count, r, g, b, amount, world.clear_r, world.clear_g, world.clear_b))
    return
end

function jg_play_sound(id::Int32)
    ptr::Ptr{World3D} = llvm_get_world3d()
    if ptr == Ptr{World3D}(C_NULL)
        return
    end
    world::World3D = unsafe_load(ptr)
    chunk::Ptr{Mix_Chunk} = Ptr{Mix_Chunk}(C_NULL)
    if id == Int32(0)
        chunk = world.snd_shot
    elseif id == Int32(1)
        chunk = world.snd_death
    elseif id == Int32(2)
        chunk = world.snd_jump
    end
    if chunk != Ptr{Mix_Chunk}(C_NULL)
        llvm_Mix_PlayChannel(Int32(-1), chunk, Int32(0))
    end
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

function fill_rect(color::Ptr{UInt8}, width::Int32, height::Int32, x::Int32, y::Int32, w::Int32, h::Int32, red::UInt8, green::UInt8, blue::UInt8)
    if w <= Int32(0) || h <= Int32(0)
        return
    end
    yy::Int32 = Int32(0)
    while yy < h
        xx::Int32 = Int32(0)
        while xx < w
            plot_hud(color, width, height, x + xx, y + yy, red, green, blue)
            xx = xx + Int32(1)
        end
        yy = yy + Int32(1)
    end
    return
end

function glyph_bits(code::Int32)::UInt64
    c::Int32 = code
    if c >= Int32(97) && c <= Int32(122)
        c = c - Int32(32)
    end
    if c == Int32(65)
        return UInt64(18842895918)
    elseif c == Int32(66)
        return UInt64(32801506878)
    elseif c == Int32(67)
        return UInt64(15620129326)
    elseif c == Int32(68)
        return UInt64(32801080894)
    elseif c == Int32(69)
        return UInt64(33840644639)
    elseif c == Int32(70)
        return UInt64(17734517279)
    elseif c == Int32(71)
        return UInt64(15621407278)
    elseif c == Int32(72)
        return UInt64(18842895921)
    elseif c == Int32(73)
        return UInt64(15170932878)
    elseif c == Int32(74)
        return UInt64(13507823687)
    elseif c == Int32(75)
        return UInt64(18879369809)
    elseif c == Int32(76)
        return UInt64(33840185872)
    elseif c == Int32(77)
        return UInt64(18842572657)
    elseif c == Int32(78)
        return UInt64(18842507057)
    elseif c == Int32(79)
        return UInt64(15621211694)
    elseif c == Int32(80)
        return UInt64(17734518334)
    elseif c == Int32(81)
        return UInt64(14585218606)
    elseif c == Int32(82)
        return UInt64(18879563326)
    elseif c == Int32(83)
        return UInt64(32247333391)
    elseif c == Int32(84)
        return UInt64(4433514655)
    elseif c == Int32(85)
        return UInt64(15621211697)
    elseif c == Int32(86)
        return UInt64(4648912433)
    elseif c == Int32(87)
        return UInt64(11464787505)
    elseif c == Int32(88)
        return UInt64(18834663985)
    elseif c == Int32(89)
        return UInt64(4433521201)
    elseif c == Int32(90)
        return UInt64(33831389247)
    elseif c == Int32(48)
        return UInt64(15629733422)
    elseif c == Int32(49)
        return UInt64(15170933124)
    elseif c == Int32(50)
        return UInt64(33558693422)
    elseif c == Int32(51)
        return UInt64(32247317566)
    elseif c == Int32(52)
        return UInt64(2217724498)
    elseif c == Int32(53)
        return UInt64(32247857695)
    elseif c == Int32(54)
        return UInt64(15621636622)
    elseif c == Int32(55)
        return UInt64(8866891839)
    elseif c == Int32(56)
        return UInt64(15621113390)
    elseif c == Int32(57)
        return UInt64(15067498030)
    elseif c == Int32(43)
        return UInt64(4357252)
    elseif c == Int32(45)
        return UInt64(31744)
    elseif c == Int32(58)
        return UInt64(138416256)
    elseif c == Int32(46)
        return UInt64(13287555072)
    elseif c == Int32(47)
        return UInt64(17043521)
    end
    return UInt64(0)
end

function draw_glyph(color::Ptr{UInt8}, width::Int32, height::Int32, x::Int32, y::Int32, scale::Int32, bits::UInt64, red::UInt8, green::UInt8, blue::UInt8)
    if scale < Int32(1)
        scale = Int32(1)
    end
    row::Int32 = Int32(0)
    while row < Int32(7)
        row_bits::UInt64 = (bits >> (row * Int32(5))) & UInt64(31)
        col::Int32 = Int32(0)
        while col < Int32(5)
            shift::Int32 = Int32(4) - col
            if ((row_bits >> shift) & UInt64(1)) != UInt64(0)
                sy::Int32 = Int32(0)
                while sy < scale
                    sx::Int32 = Int32(0)
                    while sx < scale
                        plot_hud(color, width, height, x + col * scale + sx, y + row * scale + sy, red, green, blue)
                        sx = sx + Int32(1)
                    end
                    sy = sy + Int32(1)
                end
            end
            col = col + Int32(1)
        end
        row = row + Int32(1)
    end
    return
end

function draw_hud_text(color::Ptr{UInt8}, width::Int32, height::Int32, item::HudItem)
    if item.text == Ptr{UInt8}(C_NULL)
        return
    end
    scale::Int32 = item.scale
    if scale < Int32(1)
        scale = Int32(1)
    end
    if scale > Int32(3)
        scale = Int32(3)
    end
    red::UInt8 = color_u8(item.cr)
    green::UInt8 = color_u8(item.cg)
    blue::UInt8 = color_u8(item.cb)
    cursor::Int32 = item.x
    n::Int32 = Int32(0)
    while n < Int32(28)
        ch::UInt8 = unsafe_load(item.text + Int(n))
        if ch == UInt8(0)
            return
        end
        draw_glyph(color, width, height, cursor, item.y, scale, glyph_bits(Int32(ch)), red, green, blue)
        cursor = cursor + Int32(6) * scale
        n = n + Int32(1)
    end
    return
end

function draw_hud_digits(color::Ptr{UInt8}, width::Int32, height::Int32, item::HudItem)
    scale::Int32 = item.scale
    if scale < Int32(1)
        scale = Int32(1)
    end
    if scale > Int32(3)
        scale = Int32(3)
    end
    value::Int32 = item.value
    neg::Int32 = Int32(0)
    if value < Int32(0)
        neg = Int32(1)
        value = -value
    end
    digits::Int32 = Int32(1)
    tmp::Int32 = value
    while tmp >= Int32(10) && digits < Int32(6)
        tmp = div(tmp, Int32(10))
        digits = digits + Int32(1)
    end
    if item.cr2 > digits
        digits = item.cr2
    end
    if digits > Int32(6)
        digits = Int32(6)
    end
    if digits < Int32(1)
        digits = Int32(1)
    end
    pow::Int32 = Int32(1)
    k::Int32 = Int32(1)
    while k < digits
        pow = pow * Int32(10)
        k = k + Int32(1)
    end
    red::UInt8 = color_u8(item.cr)
    green::UInt8 = color_u8(item.cg)
    blue::UInt8 = color_u8(item.cb)
    cursor::Int32 = item.x
    if neg != Int32(0)
        draw_glyph(color, width, height, cursor, item.y, scale, glyph_bits(Int32(45)), red, green, blue)
        cursor = cursor + Int32(6) * scale
    end
    k = Int32(0)
    while k < digits
        d::Int32 = Int32(0)
        if pow > Int32(0)
            d = div(value, pow)
        end
        if d > Int32(9)
            d = Int32(9)
        end
        draw_glyph(color, width, height, cursor, item.y, scale, glyph_bits(Int32(48) + d), red, green, blue)
        value = value - d * pow
        if pow > Int32(1)
            pow = div(pow, Int32(10))
        end
        cursor = cursor + Int32(6) * scale
        k = k + Int32(1)
    end
    return
end

function draw_crosshair(color::Ptr{UInt8}, width::Int32, height::Int32, gap::Int32, red::UInt8, green::UInt8, blue::UInt8)
    cx::Int32 = div(width, Int32(2))
    cy::Int32 = div(height, Int32(2))
    if gap < Int32(1)
        gap = Int32(1)
    end
    if gap > Int32(18)
        gap = Int32(18)
    end
    arm::Int32 = gap + Int32(5)
    i::Int32 = gap
    while i <= arm
        plot_hud(color, width, height, cx + i, cy, red, green, blue)
        plot_hud(color, width, height, cx - i, cy, red, green, blue)
        plot_hud(color, width, height, cx, cy + i, red, green, blue)
        plot_hud(color, width, height, cx, cy - i, red, green, blue)
        i = i + Int32(1)
    end
    return
end

function draw_hud_item(color::Ptr{UInt8}, width::Int32, height::Int32, item::HudItem)
    if item.kind == HUD_BAR
        bw::Int32 = item.w
        bh::Int32 = item.h
        if bw > Int32(200)
            bw = Int32(200)
        end
        if bh > Int32(16)
            bh = Int32(16)
        end
        fill_rect(color, width, height, item.x, item.y, bw, bh, color_u8(item.cr2), color_u8(item.cg2), color_u8(item.cb2))
        filled::Int32 = item.value
        if filled < Int32(0)
            filled = Int32(0)
        end
        if filled > Int32(100)
            filled = Int32(100)
        end
        fw::Int32 = div(bw * filled, Int32(100))
        fill_rect(color, width, height, item.x, item.y, fw, bh, color_u8(item.cr), color_u8(item.cg), color_u8(item.cb))
    elseif item.kind == HUD_DIGITS
        draw_hud_digits(color, width, height, item)
    elseif item.kind == HUD_TEXT
        draw_hud_text(color, width, height, item)
    elseif item.kind == HUD_CROSS
        draw_crosshair(color, width, height, item.value, color_u8(item.cr), color_u8(item.cg), color_u8(item.cb))
    elseif item.kind == HUD_PANEL
        pw::Int32 = item.w
        ph::Int32 = item.h
        if pw > Int32(320)
            pw = Int32(320)
        end
        if ph > Int32(240)
            ph = Int32(240)
        end
        fill_rect(color, width, height, item.x, item.y, pw, ph, color_u8(item.cr2), color_u8(item.cg2), color_u8(item.cb2))
        if pw > Int32(2) && ph > Int32(2)
            fill_rect(color, width, height, item.x + Int32(1), item.y + Int32(1), pw - Int32(2), ph - Int32(2), color_u8(item.cr), color_u8(item.cg), color_u8(item.cb))
        end
    end
    return
end

function store_view(buf::Ptr{Float64}, index::Int32, px::Float64, py::Float64, pz::Float64, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64)
    dx::Float64 = px - camx
    dy::Float64 = py - camy
    dz::Float64 = pz - camz
    yaw_c::Float64 = yaw_cos(yaw)
    yaw_s::Float64 = yaw_sin(yaw)
    pitch_c::Float64 = yaw_cos(pitch)
    pitch_s::Float64 = yaw_sin(pitch)
    tx::Float64 = dx * yaw_c - dz * yaw_s
    tz::Float64 = dx * yaw_s + dz * yaw_c
    base::Int32 = index * Int32(3)
    unsafe_store!(elem_ptr(buf, base), tx)
    unsafe_store!(elem_ptr(buf, base + Int32(1)), dy * pitch_c - tz * pitch_s)
    unsafe_store!(elem_ptr(buf, base + Int32(2)), dy * pitch_s + tz * pitch_c)
    return
end

function poly_push(buf::Ptr{Float64}, n::Int32, x::Float64, y::Float64, z::Float64)::Int32
    if n >= Int32(6)
        return n
    end
    base::Int32 = n * Int32(3)
    unsafe_store!(elem_ptr(buf, base), x)
    unsafe_store!(elem_ptr(buf, base + Int32(1)), y)
    unsafe_store!(elem_ptr(buf, base + Int32(2)), z)
    return n + Int32(1)
end

function clip_near(src::Ptr{Float64}, src_n::Int32, dst::Ptr{Float64})::Int32
    out_n::Int32 = Int32(0)
    i::Int32 = Int32(0)
    while i < src_n
        j::Int32 = i + Int32(1)
        if j >= src_n
            j = Int32(0)
        end
        ib::Int32 = i * Int32(3)
        jb::Int32 = j * Int32(3)
        ax::Float64 = unsafe_load(elem_ptr(src, ib))
        ay::Float64 = unsafe_load(elem_ptr(src, ib + Int32(1)))
        az::Float64 = unsafe_load(elem_ptr(src, ib + Int32(2)))
        bx::Float64 = unsafe_load(elem_ptr(src, jb))
        by::Float64 = unsafe_load(elem_ptr(src, jb + Int32(1)))
        bz::Float64 = unsafe_load(elem_ptr(src, jb + Int32(2)))
        ain::Int32 = Int32(0)
        bin::Int32 = Int32(0)
        if az > WORLD_NEAR
            ain = Int32(1)
        end
        if bz > WORLD_NEAR
            bin = Int32(1)
        end
        t::Float64 = 0.0
        denom::Float64 = bz - az
        if denom > 0.0000001 || denom < -0.0000001
            t = (WORLD_NEAR - az) / denom
        end
        if t < 0.0
            t = 0.0
        end
        if t > 1.0
            t = 1.0
        end
        ix::Float64 = ax + (bx - ax) * t
        iy::Float64 = ay + (by - ay) * t
        iz::Float64 = az + (bz - az) * t
        if ain != Int32(0) && bin != Int32(0)
            out_n = poly_push(dst, out_n, bx, by, bz)
        elseif ain != Int32(0) && bin == Int32(0)
            out_n = poly_push(dst, out_n, ix, iy, iz)
        elseif ain == Int32(0) && bin != Int32(0)
            out_n = poly_push(dst, out_n, ix, iy, iz)
            out_n = poly_push(dst, out_n, bx, by, bz)
        end
        i = i + Int32(1)
    end
    return out_n
end

function project_view(vx::Float64, vy::Float64, vz::Float64, width::Int32, height::Int32, out_x::Ptr{Int32}, out_y::Ptr{Int32}, out_z::Ptr{Float64})::Int32
    if vz <= WORLD_NEAR
        return Int32(0)
    end
    focal::Float64 = Float64(height) * 0.9
    screen_x::Float64 = Float64(width) * 0.5 + vx * focal / vz
    screen_y::Float64 = Float64(height) * 0.5 - vy * focal / vz
    if screen_x > 8000.0 || screen_x < -8000.0 || screen_y > 8000.0 || screen_y < -8000.0
        return Int32(0)
    end
    unsafe_store!(out_x, f64_to_i32(screen_x))
    unsafe_store!(out_y, f64_to_i32(screen_y))
    unsafe_store!(out_z, vz)
    return Int32(1)
end

function draw_view_tri(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, buf::Ptr{Float64}, i0::Int32, i1::Int32, i2::Int32, red::UInt8, green::UInt8, blue::UInt8, scratch_i::Ptr{Int32})
    b0::Int32 = i0 * Int32(3)
    b1::Int32 = i1 * Int32(3)
    b2::Int32 = i2 * Int32(3)
    zptr::Ptr{Float64} = Ptr{Float64}(Ptr{UInt8}(scratch_i) + 32)
    if project_view(unsafe_load(elem_ptr(buf, b0)), unsafe_load(elem_ptr(buf, b0 + Int32(1))), unsafe_load(elem_ptr(buf, b0 + Int32(2))), width, height, elem_ptr(scratch_i, Int32(0)), elem_ptr(scratch_i, Int32(1)), elem_ptr(zptr, Int32(0))) == Int32(0)
        return
    end
    if project_view(unsafe_load(elem_ptr(buf, b1)), unsafe_load(elem_ptr(buf, b1 + Int32(1))), unsafe_load(elem_ptr(buf, b1 + Int32(2))), width, height, elem_ptr(scratch_i, Int32(2)), elem_ptr(scratch_i, Int32(3)), elem_ptr(zptr, Int32(1))) == Int32(0)
        return
    end
    if project_view(unsafe_load(elem_ptr(buf, b2)), unsafe_load(elem_ptr(buf, b2 + Int32(1))), unsafe_load(elem_ptr(buf, b2 + Int32(2))), width, height, elem_ptr(scratch_i, Int32(4)), elem_ptr(scratch_i, Int32(5)), elem_ptr(zptr, Int32(2))) == Int32(0)
        return
    end
    x0::Int32 = unsafe_load(elem_ptr(scratch_i, Int32(0)))
    y0::Int32 = unsafe_load(elem_ptr(scratch_i, Int32(1)))
    x1::Int32 = unsafe_load(elem_ptr(scratch_i, Int32(2)))
    y1::Int32 = unsafe_load(elem_ptr(scratch_i, Int32(3)))
    x2::Int32 = unsafe_load(elem_ptr(scratch_i, Int32(4)))
    y2::Int32 = unsafe_load(elem_ptr(scratch_i, Int32(5)))
    z0::Float64 = unsafe_load(elem_ptr(zptr, Int32(0)))
    z1::Float64 = unsafe_load(elem_ptr(zptr, Int32(1)))
    z2::Float64 = unsafe_load(elem_ptr(zptr, Int32(2)))
    fog::Float64 = 1.0 - (z0 + z1 + z2) * 0.018
    if fog < 0.28
        fog = 0.28
    end
    if fog > 1.0
        fog = 1.0
    end
    draw_triangle_screen(color, depth, width, height, x0, y0, z0, x1, y1, z1, x2, y2, z2, shade_channel(Float64(red) * fog), shade_channel(Float64(green) * fog), shade_channel(Float64(blue) * fog))
    return
end

function draw_tri_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, ax::Float64, ay::Float64, az::Float64, bx::Float64, by::Float64, bz::Float64, cx::Float64, cy::Float64, cz::Float64, red::UInt8, green::UInt8, blue::UInt8, scratch::Ptr{UInt8})
    src::Ptr{Float64} = Ptr{Float64}(scratch)
    dst::Ptr{Float64} = Ptr{Float64}(scratch + 96)
    ints::Ptr{Int32} = Ptr{Int32}(scratch + 192)
    store_view(src, Int32(0), ax, ay, az, camx, camy, camz, yaw, pitch)
    store_view(src, Int32(1), bx, by, bz, camx, camy, camz, yaw, pitch)
    store_view(src, Int32(2), cx, cy, cz, camx, camy, camz, yaw, pitch)
    n::Int32 = clip_near(src, Int32(3), dst)
    if n >= Int32(3)
        draw_view_tri(color, depth, width, height, dst, Int32(0), Int32(1), Int32(2), red, green, blue, ints)
    end
    if n == Int32(4)
        draw_view_tri(color, depth, width, height, dst, Int32(0), Int32(2), Int32(3), red, green, blue, ints)
    end
    return
end

function lit_channel(value::Int32, lit::Float64)::UInt8
    if value < Int32(0)
        value = Int32(0)
    end
    if value > Int32(255)
        value = Int32(255)
    end
    return shade_channel(Float64(value) * lit)
end

function draw_quad_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, ax::Float64, ay::Float64, az::Float64, bx::Float64, by::Float64, bz::Float64, cx::Float64, cy::Float64, cz::Float64, dx::Float64, dy::Float64, dz::Float64, r::Int32, g::Int32, b::Int32, lit::Float64, scratch::Ptr{UInt8})
    rr::UInt8 = lit_channel(r, lit)
    gg::UInt8 = lit_channel(g, lit)
    bb::UInt8 = lit_channel(b, lit)
    draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, ax, ay, az, bx, by, bz, cx, cy, cz, rr, gg, bb, scratch)
    draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, ax, ay, az, cx, cy, cz, dx, dy, dz, rr, gg, bb, scratch)
    return
end

function axis_at(origin::Float64, a::Float64, sa::Float64, b::Float64, sb::Float64, c::Float64, sc::Float64)::Float64
    return origin + a * sa + b * sb + c * sc
end

function draw_viewbox_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, item::DrawItem, scratch::Ptr{UInt8})
    hx::Float64 = item.sx * 0.5
    hy::Float64 = item.sy * 0.5
    hz::Float64 = item.sz * 0.5
    rx::Float64 = item.x1
    ry::Float64 = item.y1
    rz::Float64 = item.z1
    ux::Float64 = item.x2
    uy::Float64 = item.y2
    uz::Float64 = item.z2
    fx::Float64 = item.x3
    fy::Float64 = item.y3
    fz::Float64 = item.z3
    x000::Float64 = axis_at(item.x, rx, -hx, ux, -hy, fx, -hz)
    y000::Float64 = axis_at(item.y, ry, -hx, uy, -hy, fy, -hz)
    z000::Float64 = axis_at(item.z, rz, -hx, uz, -hy, fz, -hz)
    x100::Float64 = axis_at(item.x, rx, hx, ux, -hy, fx, -hz)
    y100::Float64 = axis_at(item.y, ry, hx, uy, -hy, fy, -hz)
    z100::Float64 = axis_at(item.z, rz, hx, uz, -hy, fz, -hz)
    x010::Float64 = axis_at(item.x, rx, -hx, ux, hy, fx, -hz)
    y010::Float64 = axis_at(item.y, ry, -hx, uy, hy, fy, -hz)
    z010::Float64 = axis_at(item.z, rz, -hx, uz, hy, fz, -hz)
    x110::Float64 = axis_at(item.x, rx, hx, ux, hy, fx, -hz)
    y110::Float64 = axis_at(item.y, ry, hx, uy, hy, fy, -hz)
    z110::Float64 = axis_at(item.z, rz, hx, uz, hy, fz, -hz)
    x001::Float64 = axis_at(item.x, rx, -hx, ux, -hy, fx, hz)
    y001::Float64 = axis_at(item.y, ry, -hx, uy, -hy, fy, hz)
    z001::Float64 = axis_at(item.z, rz, -hx, uz, -hy, fz, hz)
    x101::Float64 = axis_at(item.x, rx, hx, ux, -hy, fx, hz)
    y101::Float64 = axis_at(item.y, ry, hx, uy, -hy, fy, hz)
    z101::Float64 = axis_at(item.z, rz, hx, uz, -hy, fz, hz)
    x011::Float64 = axis_at(item.x, rx, -hx, ux, hy, fx, hz)
    y011::Float64 = axis_at(item.y, ry, -hx, uy, hy, fy, hz)
    z011::Float64 = axis_at(item.z, rz, -hx, uz, hy, fz, hz)
    x111::Float64 = axis_at(item.x, rx, hx, ux, hy, fx, hz)
    y111::Float64 = axis_at(item.y, ry, hx, uy, hy, fy, hz)
    z111::Float64 = axis_at(item.z, rz, hx, uz, hy, fz, hz)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x010, y010, z010, x110, y110, z110, x111, y111, z111, x011, y011, z011, item.cr, item.cg, item.cb, 1.0, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x001, y001, z001, x101, y101, z101, x100, y100, z100, x000, y000, z000, item.cr, item.cg, item.cb, 0.32, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x100, y100, z100, x101, y101, z101, x111, y111, z111, x110, y110, z110, item.cr, item.cg, item.cb, 0.72, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x001, y001, z001, x000, y000, z000, x010, y010, z010, x011, y011, z011, item.cr, item.cg, item.cb, 0.48, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x001, y001, z001, x011, y011, z011, x111, y111, z111, x101, y101, z101, item.cr, item.cg, item.cb, 0.9, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x100, y100, z100, x000, y000, z000, x010, y010, z010, x110, y110, z110, item.cr, item.cg, item.cb, 0.55, scratch)
    return
end

function draw_box_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, item::DrawItem, scratch::Ptr{UInt8})
    hx::Float64 = item.sx * 0.5
    hy::Float64 = item.sy * 0.5
    hz::Float64 = item.sz * 0.5
    x0::Float64 = item.x - hx
    x1::Float64 = item.x + hx
    y0::Float64 = item.y - hy
    y1::Float64 = item.y + hy
    z0::Float64 = item.z - hz
    z1::Float64 = item.z + hz
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, y1, z0, x1, y1, z0, x1, y1, z1, x0, y1, z1, item.cr, item.cg, item.cb, 1.0, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, y0, z1, x1, y0, z1, x1, y0, z0, x0, y0, z0, item.cr, item.cg, item.cb, 0.32, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x1, y0, z0, x1, y0, z1, x1, y1, z1, x1, y1, z0, item.cr, item.cg, item.cb, 0.72, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, y0, z1, x0, y0, z0, x0, y1, z0, x0, y1, z1, item.cr, item.cg, item.cb, 0.48, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, item.cr, item.cg, item.cb, 0.84, scratch)
    draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x1, y0, z0, x0, y0, z0, x0, y1, z0, x1, y1, z0, item.cr, item.cg, item.cb, 0.58, scratch)
    return
end

function ring_x(angle::Float64, radius::Float64)::Float64
    return yaw_cos(angle) * radius
end

function ring_z(angle::Float64, radius::Float64)::Float64
    return yaw_sin(angle) * radius
end

function draw_cylinder_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, item::DrawItem, scratch::Ptr{UInt8})
    segments::Int32 = item.segs
    if segments < Int32(4)
        segments = Int32(4)
    end
    if segments > Int32(8)
        segments = Int32(8)
    end
    radius::Float64 = item.sx
    tall::Float64 = item.sy
    if radius < 0.02 || tall < 0.02
        return
    end
    i::Int32 = Int32(0)
    while i < segments
        a0::Float64 = Float64(i) * 6.283185307179586 / Float64(segments)
        a1::Float64 = Float64(i + Int32(1)) * 6.283185307179586 / Float64(segments)
        x0::Float64 = item.x + ring_x(a0, radius)
        z0::Float64 = item.z + ring_z(a0, radius)
        x1::Float64 = item.x + ring_x(a1, radius)
        z1::Float64 = item.z + ring_z(a1, radius)
        mid::Float64 = (a0 + a1) * 0.5
        nd::Float64 = yaw_cos(mid - yaw)
        if nd < 0.0
            nd = -nd
        end
        lit::Float64 = 0.38 + 0.62 * nd
        rr::UInt8 = lit_channel(item.cr, lit)
        gg::UInt8 = lit_channel(item.cg, lit)
        bb::UInt8 = lit_channel(item.cb, lit)
        draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, item.y, z0, x1, item.y, z1, x1, item.y + tall, z1, rr, gg, bb, scratch)
        draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, x0, item.y, z0, x1, item.y + tall, z1, x0, item.y + tall, z0, rr, gg, bb, scratch)
        draw_tri_world(color, depth, width, height, camx, camy, camz, yaw, pitch, item.x, item.y + tall, item.z, x0, item.y + tall, z0, x1, item.y + tall, z1, lit_channel(item.cr, 0.9), lit_channel(item.cg, 0.9), lit_channel(item.cb, 0.9), scratch)
        i = i + Int32(1)
    end
    return
end

function draw_grid_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, item::DrawItem, scratch::Ptr{UInt8})
    step::Float64 = item.sy
    if step < 1.0
        step = 1.0
    end
    span_x::Float64 = item.sx
    span_z::Float64 = item.sz
    if span_x <= 0.0 || span_z <= 0.0
        return
    end
    ix::Int32 = Int32(0)
    xcur::Float64 = 0.0
    while xcur < span_x - 0.001 && ix < Int32(8)
        iz::Int32 = Int32(0)
        zcur::Float64 = 0.0
        x1::Float64 = xcur + step
        if x1 > span_x
            x1 = span_x
        end
        while zcur < span_z - 0.001 && iz < Int32(8)
            z1::Float64 = zcur + step
            if z1 > span_z
                z1 = span_z
            end
            lit::Float64 = 0.82
            if ((ix + iz) & Int32(1)) == Int32(0)
                lit = 1.0
            end
            wx0::Float64 = item.x + xcur
            wz0::Float64 = item.z + zcur
            wx1::Float64 = item.x + x1
            wz1::Float64 = item.z + z1
            draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, wx0, item.y, wz0, wx1, item.y, wz0, wx1, item.y, wz1, wx0, item.y, wz1, item.cr, item.cg, item.cb, lit, scratch)
            zcur = z1
            iz = iz + Int32(1)
        end
        xcur = x1
        ix = ix + Int32(1)
    end
    return
end

function draw_item_world(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, camx::Float64, camy::Float64, camz::Float64, yaw::Float64, pitch::Float64, item::DrawItem, scratch::Ptr{UInt8})
    if item.kind == KIND_BOX
        draw_box_world(color, depth, width, height, camx, camy, camz, yaw, pitch, item, scratch)
    elseif item.kind == KIND_CYL
        draw_cylinder_world(color, depth, width, height, camx, camy, camz, yaw, pitch, item, scratch)
    elseif item.kind == KIND_QUAD
        draw_quad_world(color, depth, width, height, camx, camy, camz, yaw, pitch, item.x, item.y, item.z, item.x1, item.y1, item.z1, item.x2, item.y2, item.z2, item.x3, item.y3, item.z3, item.cr, item.cg, item.cb, 1.0, scratch)
    elseif item.kind == KIND_GRID
        draw_grid_world(color, depth, width, height, camx, camy, camz, yaw, pitch, item, scratch)
    elseif item.kind == KIND_VIEW
        draw_viewbox_world(color, depth, width, height, camx, camy, camz, yaw, pitch, item, scratch)
    end
    return
end

function clear_gradient(color::Ptr{UInt8}, depth::Ptr{Float64}, width::Int32, height::Int32, cr::Int32, cg::Int32, cb::Int32)
    y::Int32 = Int32(0)
    while y < height
        fade::Float64 = 0.62 + 0.48 * Float64(height - y) / Float64(height)
        red::UInt8 = shade_channel(Float64(cr) * fade)
        green::UInt8 = shade_channel(Float64(cg) * fade)
        blue::UInt8 = shade_channel(Float64(cb) * fade)
        x::Int32 = Int32(0)
        while x < width
            index::Int32 = y * width + x
            pixel::Ptr{UInt8} = color + (Int(index) * 4)
            unsafe_store!(pixel, red)
            unsafe_store!(pixel + 1, green)
            unsafe_store!(pixel + 2, blue)
            unsafe_store!(pixel + 3, UInt8(255))
            unsafe_store!(elem_ptr(depth, index), 0.0)
            x = x + Int32(1)
        end
        y = y + Int32(1)
    end
    return
end

function blend_flash(color::Ptr{UInt8}, count::Int32, fr::Int32, fg::Int32, fb::Int32, amount::Int32)
    if amount <= Int32(0)
        return
    end
    a::Int32 = amount
    if a > Int32(255)
        a = Int32(255)
    end
    inv::Int32 = Int32(255) - a
    i::Int32 = Int32(0)
    while i < count
        pixel::Ptr{UInt8} = color + (Int(i) * 4)
        pr::Int32 = Int32(unsafe_load(pixel))
        pg::Int32 = Int32(unsafe_load(pixel + 1))
        pb::Int32 = Int32(unsafe_load(pixel + 2))
        unsafe_store!(pixel, shade_channel(Float64(div(pr * inv + fr * a, Int32(255)))))
        unsafe_store!(pixel + 1, shade_channel(Float64(div(pg * inv + fg * a, Int32(255)))))
        unsafe_store!(pixel + 2, shade_channel(Float64(div(pb * inv + fb * a, Int32(255)))))
        i = i + Int32(1)
    end
    return
end

function render_world3d(dt::Float64)
    frame_ptr::Ptr{SoftwareFrame} = llvm_get_software_frame()
    if frame_ptr == Ptr{SoftwareFrame}(C_NULL)
        return
    end
    frame::SoftwareFrame = unsafe_load(frame_ptr)
    if frame.texture == Ptr{SDL_Texture}(C_NULL) || frame.color == Ptr{UInt8}(C_NULL) || frame.depth == Ptr{Float64}(C_NULL)
        return
    end
    world_ptr::Ptr{World3D} = llvm_get_world3d()
    cr::Int32 = Int32(22)
    cg::Int32 = Int32(18)
    cb::Int32 = Int32(32)
    world::World3D = World3D(Ptr{DrawItem}(C_NULL), Int32(0), Ptr{Aabb}(C_NULL), Int32(0), Ptr{HitSphere}(C_NULL), Int32(0), Ptr{HudItem}(C_NULL), Int32(0), Ptr{Mix_Chunk}(C_NULL), Ptr{Mix_Chunk}(C_NULL), Ptr{Mix_Chunk}(C_NULL), Ptr{Cvoid}(C_NULL), Int32(0), Int32(0), Int32(0), Int32(0), cr, cg, cb)
    if world_ptr != Ptr{World3D}(C_NULL)
        world = unsafe_load(world_ptr)
        cr = world.clear_r
        cg = world.clear_g
        cb = world.clear_b
    end
    clear_gradient(frame.color, frame.depth, frame.width, frame.height, cr, cg, cb)
    camx::Float64 = llvm_game_cam_x()
    camy::Float64 = llvm_game_cam_y()
    camz::Float64 = llvm_game_cam_z()
    yaw::Float64 = llvm_game_cam_yaw()
    pitch::Float64 = llvm_game_cam_pitch()
    if pitch > 1.45
        pitch = 1.45
    end
    if pitch < -1.35
        pitch = -1.35
    end
    if world.draws != Ptr{DrawItem}(C_NULL) && world.draw_count > Int32(0)
        scratch::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(UInt32(256)))
        if scratch != Ptr{UInt8}(C_NULL)
            di::Int32 = Int32(0)
            while di < world.draw_count
                item::DrawItem = unsafe_load(elem_ptr(world.draws, di))
                draw_item_world(frame.color, frame.depth, frame.width, frame.height, camx, camy, camz, yaw, pitch, item, scratch)
                di = di + Int32(1)
            end
            wasm_free(scratch)
        end
    end
    if world.flash_a > Int32(0)
        blend_flash(frame.color, frame.width * frame.height, world.flash_r, world.flash_g, world.flash_b, world.flash_a)
        next_a::Int32 = world.flash_a - f64_to_i32(dt * 420.0)
        if next_a < Int32(0)
            next_a = Int32(0)
        end
        if world_ptr != Ptr{World3D}(C_NULL)
            unsafe_store!(world_ptr, copy_world(world, world.draw_count, world.aabb_count, world.sphere_count, world.hud_count, world.flash_r, world.flash_g, world.flash_b, next_a, world.clear_r, world.clear_g, world.clear_b))
        end
    end
    if world.huds != Ptr{HudItem}(C_NULL)
        hi::Int32 = Int32(0)
        while hi < world.hud_count
            hud::HudItem = unsafe_load(elem_ptr(world.huds, hi))
            draw_hud_item(frame.color, frame.width, frame.height, hud)
            hi = hi + Int32(1)
        end
    end
    pitch_bytes::Int32 = frame.width * Int32(4)
    llvm_SDL_UpdateTexture(frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{Cvoid}(frame.color), pitch_bytes)
    llvm_SDL_RenderCopy(llvm_get_renderer(), frame.texture, Ptr{SDL_Rect}(C_NULL), Ptr{SDL_Rect}(C_NULL))
    return
end
