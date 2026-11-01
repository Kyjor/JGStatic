# Arena-backed scene. One count pass, then one fill pass. No Vector, Dict, or String.
# Scripts are skipped. Component `type` selects Transform, Sprite, Collider, Rigidbody,
# SoundSource, Shape, or Animator. Anything else is ignored.

const MODE_COUNT = Int32(0)
const MODE_FILL = Int32(1)
const SCENE_ARENA_BYTES = UInt32(2 * 1024 * 1024)
const SCENE_FILE_MAX = UInt32(8 * 1024 * 1024)

struct Arena
    base::Ptr{UInt8}
    capacity::UInt32
    used::UInt32
end

struct FileBytes
    ptr::Ptr{UInt8}
    len::UInt32
end

struct SceneEntity
    name::ByteSpan
    id::ByteSpan
    parent_id::ByteSpan
    parent_index::Int32
    is_active::Int32
    persistent::Int32
    transform::Int32
    sprite::Int32
    collider::Int32
    rigidbody::Int32
    sound::Int32
    shape::Int32
    animator::Int32
end

struct SceneTransform
    entity::Int32
    px::Float64
    py::Float64
    pz::Float64
    sx::Float64
    sy::Float64
    sz::Float64
end

struct SceneSprite
    entity::Int32
    image::ByteSpan
    layer::Int32
    pixels_per_unit::Int32
    is_flipped::Int32
    is_world::Int32
    rotation::Float64
    px::Float64
    py::Float64
    ox::Float64
    oy::Float64
    cx::Float64
    cy::Float64
    width::Float64
    height::Float64
    cropx::Float64
    cropy::Float64
    cropz::Float64
    cropt::Float64
    has_crop::Int32
    red::Int32
    green::Int32
    blue::Int32
    color_a::Int32
end

struct SceneCollider
    entity::Int32
    tag::ByteSpan
    enabled::Int32
    is_platformer::Int32
    is_trigger::Int32
    ox::Float64
    oy::Float64
    width::Float64
    height::Float64
end

struct SceneRigidbody
    entity::Int32
    mass::Float64
    drag::Float64
    use_gravity::Int32
end

struct SceneSound
    entity::Int32
    path::ByteSpan
    channel::Int32
    volume::Int32
    is_music::Int32
    play_on_start::Int32
end

struct SceneShape
    entity::Int32
    red::Int32
    green::Int32
    blue::Int32
    is_filled::Int32
    is_world::Int32
    layer::Int32
    alpha::Int32
    ox::Float64
    oy::Float64
    px::Float64
    py::Float64
    width::Float64
    height::Float64
end

struct SceneFrame
    x::Float64
    y::Float64
    z::Float64
    t::Float64
end

struct SceneAnimation
    fps::Int32
    frame_begin::Int32
    frame_count::Int32
end

struct SceneAnimator
    entity::Int32
    anim_begin::Int32
    anim_count::Int32
end

struct SceneUI
    kind::ByteSpan
    name::ByteSpan
    id::ByteSpan
    text::ByteSpan
    font_path::ByteSpan
    parent_index::Int32
    is_active::Int32
    font_size::Int32
    x::Float64
    y::Float64
    width::Float64
    height::Float64
end

struct SceneCamera
    present::Int32
    px::Float64
    py::Float64
    sx::Float64
    sy::Float64
    ox::Float64
    oy::Float64
    zoom::Float64
    br::Int32
    bg::Int32
    bb::Int32
    ba::Int32
end

struct CompFields
    image::ByteSpan
    tag::ByteSpan
    path::ByteSpan
    px::Float64
    py::Float64
    pz::Float64
    sx::Float64
    sy::Float64
    sz::Float64
    ox::Float64
    oy::Float64
    cx::Float64
    cy::Float64
    width::Float64
    height::Float64
    cropx::Float64
    cropy::Float64
    cropz::Float64
    cropt::Float64
    rotation::Float64
    mass::Float64
    drag::Float64
    layer::Int32
    pixels_per_unit::Int32
    is_flipped::Int32
    is_world::Int32
    enabled::Int32
    is_platformer::Int32
    is_trigger::Int32
    use_gravity::Int32
    channel::Int32
    volume::Int32
    is_music::Int32
    play_on_start::Int32
    is_filled::Int32
    alpha::Int32
    has_crop::Int32
    red::Int32
    green::Int32
    blue::Int32
    color_a::Int32
end

struct Scene
    file_bytes::Ptr{UInt8}
    file_size::UInt32
    arena::Ptr{Arena}
    entities::Ptr{SceneEntity}
    entity_count::Int32
    transforms::Ptr{SceneTransform}
    transform_count::Int32
    sprites::Ptr{SceneSprite}
    sprite_count::Int32
    colliders::Ptr{SceneCollider}
    collider_count::Int32
    rigidbodies::Ptr{SceneRigidbody}
    rigidbody_count::Int32
    sounds::Ptr{SceneSound}
    sound_count::Int32
    shapes::Ptr{SceneShape}
    shape_count::Int32
    animators::Ptr{SceneAnimator}
    animator_count::Int32
    animations::Ptr{SceneAnimation}
    animation_count::Int32
    frames::Ptr{SceneFrame}
    frame_count::Int32
    ui::Ptr{SceneUI}
    ui_count::Int32
    camera::SceneCamera
    print_buf::Ptr{UInt8}
    scratch_entity::Ptr{SceneEntity}
    scratch_fields::Ptr{CompFields}
end

function blank_entity()::SceneEntity
    empty::ByteSpan = blank_span()
    return SceneEntity(empty, empty, empty, Int32(-1), Int32(1), Int32(0), Int32(-1), Int32(-1), Int32(-1), Int32(-1), Int32(-1), Int32(-1), Int32(-1))
end

function blank_fields()::CompFields
    empty::ByteSpan = blank_span()
    return CompFields(
        empty, empty, empty,
        0.0, 0.0, 0.0,
        1.0, 1.0, 1.0,
        0.0, 0.0,
        0.5, 0.5,
        0.0, 0.0,
        0.0, 0.0, 0.0, 0.0,
        0.0,
        1.0, 0.0,
        Int32(0), Int32(-1), Int32(0), Int32(1), Int32(1), Int32(0), Int32(0), Int32(1),
        Int32(-1), Int32(-1), Int32(0), Int32(0), Int32(1), Int32(255), Int32(0),
        Int32(255), Int32(255), Int32(255), Int32(255),
    )
end

function blank_camera()::SceneCamera
    return SceneCamera(Int32(0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, Int32(0), Int32(0), Int32(0), Int32(255))
end

function llvm_fopen(path::Ptr{UInt8}, mode::Ptr{UInt8})::Ptr{Cvoid}
    return Base.llvmcall(("""
        declare i8* @fopen(i8*, i8*) nounwind
        define i8* @main(i8* %path, i8* %mode) {
        entry:
            %r = call i8* @fopen(i8* %path, i8* %mode)
            ret i8* %r
        }
    """, "main"), Ptr{Cvoid}, Tuple{Ptr{UInt8}, Ptr{UInt8}}, path, mode)
end

function llvm_fseek(file::Ptr{Cvoid}, offset::Int64, whence::Int32)::Int32
    return Base.llvmcall(("""
        declare i32 @fseek(i8*, i64, i32) nounwind
        define i32 @main(i8* %file, i64 %offset, i32 %whence) {
        entry:
            %r = call i32 @fseek(i8* %file, i64 %offset, i32 %whence)
            ret i32 %r
        }
    """, "main"), Int32, Tuple{Ptr{Cvoid}, Int64, Int32}, file, offset, whence)
end

function llvm_ftell(file::Ptr{Cvoid})::Int64
    return Base.llvmcall(("""
        declare i64 @ftell(i8*) nounwind
        define i64 @main(i8* %file) {
        entry:
            %r = call i64 @ftell(i8* %file)
            ret i64 %r
        }
    """, "main"), Int64, Tuple{Ptr{Cvoid}}, file)
end

function llvm_fread(buf::Ptr{UInt8}, size::Int64, count::Int64, file::Ptr{Cvoid})::Int64
    return Base.llvmcall(("""
        declare i64 @fread(i8*, i64, i64, i8*) nounwind
        define i64 @main(i8* %buf, i64 %size, i64 %count, i8* %file) {
        entry:
            %r = call i64 @fread(i8* %buf, i64 %size, i64 %count, i8* %file)
            ret i64 %r
        }
    """, "main"), Int64, Tuple{Ptr{UInt8}, Int64, Int64, Ptr{Cvoid}}, buf, size, count, file)
end

function llvm_fclose(file::Ptr{Cvoid})::Int32
    return Base.llvmcall(("""
        declare i32 @fclose(i8*) nounwind
        define i32 @main(i8* %file) {
        entry:
            %r = call i32 @fclose(i8* %file)
            ret i32 %r
        }
    """, "main"), Int32, Tuple{Ptr{Cvoid}}, file)
end

function read_file(path::Ptr{UInt8})::FileBytes
    none::FileBytes = FileBytes(Ptr{UInt8}(C_NULL), UInt32(0))
    mode::Ptr{UInt8} = str_ptr(w"rb")
    file::Ptr{Cvoid} = llvm_fopen(path, mode)
    wasm_free(mode)
    if file == Ptr{Cvoid}(C_NULL)
        printf(c"failed to open scene\n")
        return none
    end
    if llvm_fseek(file, Int64(0), Int32(2)) != Int32(0)
        llvm_fclose(file)
        printf(c"failed to seek scene\n")
        return none
    end
    size64::Int64 = llvm_ftell(file)
    if size64 <= Int64(0) || size64 > Int64(SCENE_FILE_MAX)
        llvm_fclose(file)
        printf(c"scene file size rejected\n")
        return none
    end
    if llvm_fseek(file, Int64(0), Int32(0)) != Int32(0)
        llvm_fclose(file)
        return none
    end
    nbytes::UInt32 = size64 % UInt32
    buf::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(nbytes))
    if buf == Ptr{UInt8}(C_NULL)
        llvm_fclose(file)
        return none
    end
    got::Int64 = llvm_fread(buf, Int64(1), Int64(nbytes), file)
    llvm_fclose(file)
    if got != Int64(nbytes)
        wasm_free(buf)
        printf(c"failed to read scene\n")
        return none
    end
    return FileBytes(buf, nbytes)
end

function arena_create(capacity::UInt32)::Ptr{Arena}
    header::Ptr{Arena} = Ptr{Arena}(wasm_malloc(UInt32(sizeof(Arena))))
    block::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(capacity))
    if header == Ptr{Arena}(C_NULL) || block == Ptr{UInt8}(C_NULL)
        return Ptr{Arena}(C_NULL)
    end
    unsafe_store!(header, Arena(block, capacity, UInt32(0)))
    return header
end

function arena_alloc(arena::Ptr{Arena}, nbytes::UInt32)::Ptr{UInt8}
    if arena == Ptr{Arena}(C_NULL)
        return Ptr{UInt8}(C_NULL)
    end
    used::UInt32 = arena.used
    mask::UInt32 = UInt32(7)
    aligned::UInt32 = (used + mask) & ~mask
    if aligned + nbytes > arena.capacity
        printf(c"scene arena exhausted\n")
        return Ptr{UInt8}(C_NULL)
    end
    arena.used = aligned + nbytes
    return arena.base + Int(aligned)
end

function arena_array(arena::Ptr{Arena}, ::Type{T}, count::Int32)::Ptr{T} where {T}
    if count <= Int32(0)
        return Ptr{T}(C_NULL)
    end
    bytes::UInt32 = (count % UInt32) * UInt32(sizeof(T))
    p::Ptr{UInt8} = arena_alloc(arena, bytes)
    if p == Ptr{UInt8}(C_NULL)
        return Ptr{T}(C_NULL)
    end
    return Ptr{T}(p)
end

function arena_store_i32(arena::Ptr{Arena}, value::Int32)::ByteSpan
    raw::Int32 = value
    neg::Int32 = Int32(0)
    if raw < Int32(0)
        neg = Int32(1)
        raw = Int32(0) - raw
    end
    buf::Ptr{UInt8} = arena_alloc(arena, UInt32(16))
    if buf == Ptr{UInt8}(C_NULL)
        return blank_span()
    end
    digits::Int32 = Int32(0)
    if raw == Int32(0)
        digits = Int32(1)
    else
        t::Int32 = raw
        while t > Int32(0)
            digits += Int32(1)
            t = div(t, Int32(10))
        end
    end
    len::Int32 = digits + neg
    pos::Int32 = len - Int32(1)
    n::Int32 = raw
    if n == Int32(0)
        unsafe_store!(buf + Int(pos), UInt8('0'))
    else
        while n > Int32(0)
            unsafe_store!(buf + Int(pos), UInt8('0') + (rem(n, Int32(10)) % UInt8))
            n = div(n, Int32(10))
            pos -= Int32(1)
        end
    end
    if neg == Int32(1)
        unsafe_store!(buf, UInt8('-'))
    end
    return ByteSpan(buf, len % UInt32)
end

function read_id!(arena::Ptr{Arena}, c::Ptr{JsonCursor}, mode::Int32)::ByteSpan
    skip_ws!(c)
    if peek(c) == UInt8('"')
        return scan_string!(c)
    end
    n::Float64 = read_number!(c)
    if mode != MODE_FILL
        return blank_span()
    end
    return arena_store_i32(arena, f64_to_i32(n))
end

function read_parent!(c::Ptr{JsonCursor})::ByteSpan
    skip_ws!(c)
    b::UInt8 = peek(c)
    if b == UInt8('"')
        return scan_string!(c)
    end
    if b != UInt8('{')
        skip_value!(c)
        return blank_span()
    end
    found::ByteSpan = blank_span()
    if begin_container!(c, UInt8('{')) != Int32(0)
        return found
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        if key_is(step.key, k"id") == Int32(1)
            found = scan_string!(c)
        else
            skip_value!(c)
        end
    end
    return found
end

function spans_eq(a::ByteSpan, b::ByteSpan)::Int32
    if a.len == UInt32(0) || a.len != b.len
        return Int32(0)
    end
    i::UInt32 = UInt32(0)
    while i < a.len
        if unsafe_load(a.ptr + Int(i)) != unsafe_load(b.ptr + Int(i))
            return Int32(0)
        end
        i += UInt32(1)
    end
    return Int32(1)
end

@inline function elem_ptr(ptr::Ptr{T}, index::Int32)::Ptr{T} where {T}
    return ptr + Int(index) * sizeof(T)
end

function store_item!(mode::Int32, ptr::Ptr{T}, count::Int32, value::T)::Int32 where {T}
    if mode == MODE_FILL && ptr != Ptr{T}(C_NULL)
        unsafe_store!(elem_ptr(ptr, count), value)
    end
    return count + Int32(1)
end

function find_type!(c::Ptr{JsonCursor})::ByteSpan
    start::UInt32 = c.pos
    found::ByteSpan = blank_span()
    if begin_container!(c, UInt8('{')) != Int32(0)
        c.pos = start
        return found
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        if key_is(step.key, k"type") == Int32(1)
            found = scan_string!(c)
        else
            skip_value!(c)
        end
    end
    c.pos = start
    return found
end

function fill_component_fields!(c::Ptr{JsonCursor}, fields::Ptr{CompFields})
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            return
        end
        key::ByteSpan = step.key
        if key_is(key, k"type") == Int32(1)
            scan_string!(c)
        elseif key_is(key, k"imagePath") == Int32(1)
            fields.image = scan_string!(c)
        elseif key_is(key, k"tag") == Int32(1)
            fields.tag = scan_string!(c)
        elseif key_is(key, k"path") == Int32(1)
            fields.path = scan_string!(c)
        elseif key_is(key, k"position") == Int32(1)
            v::SceneVec3 = read_vec3!(c, 0.0, 0.0, 0.0)
            fields.px = v.x
            fields.py = v.y
            fields.pz = v.z
        elseif key_is(key, k"scale") == Int32(1)
            v = read_vec3!(c, 1.0, 1.0, 1.0)
            fields.sx = v.x
            fields.sy = v.y
            fields.sz = v.z
        elseif key_is(key, k"offset") == Int32(1)
            v2::Vector2f = read_vec2!(c, 0.0, 0.0)
            fields.ox = v2.x
            fields.oy = v2.y
        elseif key_is(key, k"center") == Int32(1)
            v2 = read_vec2!(c, 0.5, 0.5)
            fields.cx = v2.x
            fields.cy = v2.y
        elseif key_is(key, k"size") == Int32(1)
            v2 = read_vec2!(c, 0.0, 0.0)
            fields.width = v2.x
            fields.height = v2.y
        elseif key_is(key, k"crop") == Int32(1)
            crop::SceneVec4 = read_vec4!(c)
            fields.cropx = crop.x
            fields.cropy = crop.y
            fields.cropz = crop.z
            fields.cropt = crop.t
            fields.has_crop = Int32(1)
        elseif key_is(key, k"color") == Int32(1)
            col::SceneColor = read_color!(c)
            fields.red = col.r
            fields.green = col.g
            fields.blue = col.b
            fields.color_a = col.a
        elseif key_is(key, k"rotation") == Int32(1)
            fields.rotation = read_number!(c)
        elseif key_is(key, k"layer") == Int32(1)
            fields.layer = f64_to_i32(read_number!(c))
        elseif key_is(key, k"pixelsPerUnit") == Int32(1)
            fields.pixels_per_unit = f64_to_i32(read_number!(c))
        elseif key_is(key, k"isFlipped") == Int32(1)
            fields.is_flipped = read_bool!(c)
        elseif key_is(key, k"isWorldEntity") == Int32(1)
            fields.is_world = read_bool!(c)
        elseif key_is(key, k"enabled") == Int32(1)
            fields.enabled = read_bool!(c)
        elseif key_is(key, k"isPlatformerCollider") == Int32(1)
            fields.is_platformer = read_bool!(c)
        elseif key_is(key, k"isTrigger") == Int32(1)
            fields.is_trigger = read_bool!(c)
        elseif key_is(key, k"mass") == Int32(1)
            fields.mass = read_number!(c)
        elseif key_is(key, k"drag") == Int32(1)
            fields.drag = read_number!(c)
        elseif key_is(key, k"useGravity") == Int32(1)
            fields.use_gravity = read_bool!(c)
        elseif key_is(key, k"channel") == Int32(1)
            fields.channel = f64_to_i32(read_number!(c))
        elseif key_is(key, k"volume") == Int32(1)
            fields.volume = f64_to_i32(read_number!(c))
        elseif key_is(key, k"isMusic") == Int32(1)
            fields.is_music = read_bool!(c)
        elseif key_is(key, k"playOnStart") == Int32(1)
            fields.play_on_start = read_bool!(c)
        elseif key_is(key, k"isFilled") == Int32(1)
            fields.is_filled = read_bool!(c)
        elseif key_is(key, k"alpha") == Int32(1)
            fields.alpha = f64_to_i32(read_number!(c))
        else
            skip_value!(c)
        end
    end
    return
end

function read_frame_array!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, mode::Int32)
    if begin_container!(c, UInt8('[')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::Int32 = next_element!(c)
        if step != Int32(1)
            return
        end
        frame::SceneVec4 = read_vec4!(c)
        scene.frame_count = store_item!(mode, scene.frames, scene.frame_count, SceneFrame(frame.x, frame.y, frame.z, frame.t))
    end
end

function read_animation_array!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, mode::Int32)
    if begin_container!(c, UInt8('[')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::Int32 = next_element!(c)
        if step != Int32(1)
            return
        end
        frame_begin::Int32 = scene.frame_count
        fps::Int32 = Int32(60)
        if begin_container!(c, UInt8('{')) != Int32(0)
            skip_value!(c)
            continue
        end
        while true
            keystep::KeyStep = next_key!(c)
            if keystep.status != Int32(1)
                break
            end
            if key_is(keystep.key, k"animatedFPS") == Int32(1)
                fps = f64_to_i32(read_number!(c))
            elseif key_is(keystep.key, k"frames") == Int32(1)
                read_frame_array!(scene, c, mode)
            else
                skip_value!(c)
            end
        end
        anim::SceneAnimation = SceneAnimation(fps, frame_begin, scene.frame_count - frame_begin)
        scene.animation_count = store_item!(mode, scene.animations, scene.animation_count, anim)
    end
end

function read_animator!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, entity_index::Int32, entity::Ptr{SceneEntity}, mode::Int32)
    anim_begin::Int32 = scene.animation_count
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        if key_is(step.key, k"animations") == Int32(1)
            read_animation_array!(scene, c, mode)
        else
            skip_value!(c)
        end
    end
    index::Int32 = scene.animator_count
    scene.animator_count = store_item!(mode, scene.animators, index, SceneAnimator(entity_index, anim_begin, scene.animation_count - anim_begin))
    entity.animator = index
    return
end

function commit_component!(scene::Ptr{Scene}, entity::Ptr{SceneEntity}, entity_index::Int32, kind::ByteSpan, mode::Int32)
    fields::CompFields = unsafe_load(scene.scratch_fields)
    if key_is(kind, k"Transform") == Int32(1)
        index::Int32 = scene.transform_count
        scene.transform_count = store_item!(mode, scene.transforms, index, SceneTransform(entity_index, fields.px, fields.py, fields.pz, fields.sx, fields.sy, fields.sz))
        entity.transform = index
    elseif key_is(kind, k"Sprite") == Int32(1)
        index = scene.sprite_count
        scene.sprite_count = store_item!(mode, scene.sprites, index, SceneSprite(
            entity_index, fields.image, fields.layer, fields.pixels_per_unit, fields.is_flipped, fields.is_world, fields.rotation,
            fields.px, fields.py, fields.ox, fields.oy, fields.cx, fields.cy, fields.width, fields.height,
            fields.cropx, fields.cropy, fields.cropz, fields.cropt, fields.has_crop,
            fields.red, fields.green, fields.blue, fields.color_a,
        ))
        entity.sprite = index
    elseif key_is(kind, k"Collider") == Int32(1)
        index = scene.collider_count
        scene.collider_count = store_item!(mode, scene.colliders, index, SceneCollider(
            entity_index, fields.tag, fields.enabled, fields.is_platformer, fields.is_trigger, fields.ox, fields.oy, fields.width, fields.height,
        ))
        entity.collider = index
    elseif key_is(kind, k"Rigidbody") == Int32(1)
        index = scene.rigidbody_count
        scene.rigidbody_count = store_item!(mode, scene.rigidbodies, index, SceneRigidbody(entity_index, fields.mass, fields.drag, fields.use_gravity))
        entity.rigidbody = index
    elseif key_is(kind, k"SoundSource") == Int32(1)
        index = scene.sound_count
        scene.sound_count = store_item!(mode, scene.sounds, index, SceneSound(entity_index, fields.path, fields.channel, fields.volume, fields.is_music, fields.play_on_start))
        entity.sound = index
    elseif key_is(kind, k"Shape") == Int32(1)
        w::Float64 = fields.width
        h::Float64 = fields.height
        if w == 0.0 && h == 0.0
            w = 1.0
            h = 1.0
        end
        index = scene.shape_count
        scene.shape_count = store_item!(mode, scene.shapes, index, SceneShape(
            entity_index, fields.red, fields.green, fields.blue, fields.is_filled, fields.is_world, fields.layer, fields.alpha,
            fields.ox, fields.oy, fields.px, fields.py, w, h,
        ))
        entity.shape = index
    end
    return
end

function read_component!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, entity_index::Int32, entity::Ptr{SceneEntity}, mode::Int32)
    kind::ByteSpan = find_type!(c)
    if kind.len == UInt32(0)
        skip_object!(c)
        return
    end
    if key_is(kind, k"Animator") == Int32(1)
        read_animator!(scene, c, entity_index, entity, mode)
        return
    end
    if key_is(kind, k"Transform") != Int32(1) && key_is(kind, k"Sprite") != Int32(1) && key_is(kind, k"Collider") != Int32(1) && key_is(kind, k"Rigidbody") != Int32(1) && key_is(kind, k"SoundSource") != Int32(1) && key_is(kind, k"Shape") != Int32(1)
        skip_object!(c)
        return
    end
    unsafe_store!(scene.scratch_fields, blank_fields())
    fill_component_fields!(c, scene.scratch_fields)
    commit_component!(scene, entity, entity_index, kind, mode)
    return
end

function read_components!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, entity_index::Int32, entity::Ptr{SceneEntity}, mode::Int32)
    if begin_container!(c, UInt8('[')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::Int32 = next_element!(c)
        if step != Int32(1)
            return
        end
        read_component!(scene, c, entity_index, entity, mode)
    end
end

function read_entity!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, mode::Int32)
    index::Int32 = scene.entity_count
    scene.entity_count = index + Int32(1)
    entity::Ptr{SceneEntity} = scene.scratch_entity
    unsafe_store!(entity, blank_entity())
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        key::ByteSpan = step.key
        if key_is(key, k"name") == Int32(1)
            entity.name = scan_string!(c)
        elseif key_is(key, k"id") == Int32(1)
            entity.id = read_id!(scene.arena, c, mode)
        elseif key_is(key, k"isActive") == Int32(1)
            entity.is_active = read_bool!(c)
        elseif key_is(key, k"persistentBetweenScenes") == Int32(1)
            entity.persistent = read_bool!(c)
        elseif key_is(key, k"parent") == Int32(1)
            entity.parent_id = read_parent!(c)
        elseif key_is(key, k"components") == Int32(1)
            read_components!(scene, c, index, entity, mode)
        else
            skip_value!(c)
        end
    end
    if mode == MODE_FILL && scene.entities != Ptr{SceneEntity}(C_NULL)
        unsafe_store!(elem_ptr(scene.entities, index), unsafe_load(entity))
    end
    return
end

function read_entities!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, mode::Int32)
    if begin_container!(c, UInt8('[')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::Int32 = next_element!(c)
        if step != Int32(1)
            return
        end
        read_entity!(scene, c, mode)
    end
end

function read_ui!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, parent_index::Int32, mode::Int32)
    index::Int32 = scene.ui_count
    scene.ui_count = index + Int32(1)
    kind::ByteSpan = blank_span()
    name::ByteSpan = blank_span()
    id::ByteSpan = blank_span()
    text::ByteSpan = blank_span()
    font_path::ByteSpan = blank_span()
    is_active::Int32 = Int32(1)
    font_size::Int32 = Int32(0)
    x::Float64 = 0.0
    y::Float64 = 0.0
    width::Float64 = 0.0
    height::Float64 = 0.0
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        key::ByteSpan = step.key
        if key_is(key, k"type") == Int32(1)
            kind = scan_string!(c)
        elseif key_is(key, k"name") == Int32(1)
            name = scan_string!(c)
        elseif key_is(key, k"id") == Int32(1)
            id = read_id!(scene.arena, c, mode)
        elseif key_is(key, k"text") == Int32(1)
            text = scan_string!(c)
        elseif key_is(key, k"fontPath") == Int32(1)
            font_path = scan_string!(c)
        elseif key_is(key, k"fontSize") == Int32(1)
            font_size = f64_to_i32(read_number!(c))
        elseif key_is(key, k"isActive") == Int32(1)
            is_active = read_bool!(c)
        elseif key_is(key, k"position") == Int32(1)
            pos::Vector2f = read_vec2!(c, 0.0, 0.0)
            x = pos.x
            y = pos.y
        elseif key_is(key, k"size") == Int32(1)
            sz::Vector2f = read_vec2!(c, 0.0, 0.0)
            width = sz.x
            height = sz.y
        elseif key_is(key, k"children") == Int32(1)
            read_ui_array!(scene, c, index, mode)
        else
            skip_value!(c)
        end
    end
    if mode == MODE_FILL && scene.ui != Ptr{SceneUI}(C_NULL)
        unsafe_store!(elem_ptr(scene.ui, index), SceneUI(kind, name, id, text, font_path, parent_index, is_active, font_size, x, y, width, height))
    end
    return
end

function read_ui_array!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, parent_index::Int32, mode::Int32)
    if begin_container!(c, UInt8('[')) != Int32(0)
        skip_value!(c)
        return
    end
    while true
        step::Int32 = next_element!(c)
        if step != Int32(1)
            return
        end
        read_ui!(scene, c, parent_index, mode)
    end
end

function read_camera!(scene::Ptr{Scene}, c::Ptr{JsonCursor})
    cam::SceneCamera = blank_camera()
    cam = SceneCamera(Int32(1), cam.px, cam.py, cam.sx, cam.sy, cam.ox, cam.oy, cam.zoom, cam.br, cam.bg, cam.bb, cam.ba)
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        scene.camera = cam
        return
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        key::ByteSpan = step.key
        if key_is(key, k"position") == Int32(1)
            v::SceneVec3 = read_vec3!(c, 0.0, 0.0, 0.0)
            cam = SceneCamera(cam.present, v.x, v.y, cam.sx, cam.sy, cam.ox, cam.oy, cam.zoom, cam.br, cam.bg, cam.bb, cam.ba)
        elseif key_is(key, k"size") == Int32(1)
            v2::Vector2f = read_vec2!(c, 0.0, 0.0)
            cam = SceneCamera(cam.present, cam.px, cam.py, v2.x, v2.y, cam.ox, cam.oy, cam.zoom, cam.br, cam.bg, cam.bb, cam.ba)
        elseif key_is(key, k"offset") == Int32(1)
            v2 = read_vec2!(c, 0.0, 0.0)
            cam = SceneCamera(cam.present, cam.px, cam.py, cam.sx, cam.sy, v2.x, v2.y, cam.zoom, cam.br, cam.bg, cam.bb, cam.ba)
        elseif key_is(key, k"zoom") == Int32(1)
            cam = SceneCamera(cam.present, cam.px, cam.py, cam.sx, cam.sy, cam.ox, cam.oy, read_number!(c), cam.br, cam.bg, cam.bb, cam.ba)
        elseif key_is(key, k"backgroundColor") == Int32(1)
            col::SceneColor = read_color!(c)
            cam = SceneCamera(cam.present, cam.px, cam.py, cam.sx, cam.sy, cam.ox, cam.oy, cam.zoom, col.r, col.g, col.b, col.a)
        else
            skip_value!(c)
        end
    end
    scene.camera = cam
    return
end

function read_root!(scene::Ptr{Scene}, c::Ptr{JsonCursor}, mode::Int32)::Int32
    if begin_container!(c, UInt8('{')) != Int32(0)
        printf(c"scene json is not an object\n")
        return Int32(-1)
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            return step.status
        end
        if key_is(step.key, k"Entities") == Int32(1)
            read_entities!(scene, c, mode)
        elseif key_is(step.key, k"Camera") == Int32(1)
            read_camera!(scene, c)
        elseif key_is(step.key, k"UIElements") == Int32(1)
            read_ui_array!(scene, c, Int32(-1), mode)
        else
            skip_value!(c)
        end
    end
end

function resolve_parents!(scene::Ptr{Scene})
    i::Int32 = Int32(0)
    while i < scene.entity_count
        eptr::Ptr{SceneEntity} = elem_ptr(scene.entities, i)
        parent_id::ByteSpan = eptr.parent_id
        if parent_id.len != UInt32(0)
            j::Int32 = Int32(0)
            while j < scene.entity_count
                other::SceneEntity = unsafe_load(elem_ptr(scene.entities, j))
                if spans_eq(parent_id, other.id) == Int32(1)
                    eptr.parent_index = j
                    break
                end
                j += Int32(1)
            end
        end
        i += Int32(1)
    end
    return
end

function print_span(scene::Ptr{Scene}, span::ByteSpan)
    if span.ptr == Ptr{UInt8}(C_NULL) || span.len == UInt32(0)
        printf(c"(empty)")
        return
    end
    n::UInt32 = span.len
    if n > UInt32(255)
        n = UInt32(255)
    end
    buf::Ptr{UInt8} = scene.print_buf
    i::UInt32 = UInt32(0)
    while i < n
        unsafe_store!(buf + Int(i), unsafe_load(span.ptr + Int(i)))
        i += UInt32(1)
    end
    unsafe_store!(buf + Int(n), UInt8(0))
    printf(c"%s", buf)
    return
end

function print_scene(scene::Ptr{Scene})
    if scene.entity_count > Int32(0) && scene.entities == Ptr{SceneEntity}(C_NULL)
        printf(c"scene tables missing\n")
        return
    end
    printf(c"entities ")
    printf(c"%d", scene.entity_count)
    printf(c" sprites ")
    printf(c"%d", scene.sprite_count)
    printf(c" transforms ")
    printf(c"%d", scene.transform_count)
    printf(c" ui ")
    printf(c"%d\n", scene.ui_count)
    cam::SceneCamera = scene.camera
    if cam.present == Int32(1)
        printf(c"camera ")
        printf(c"%f", cam.px)
        printf(c" ")
        printf(c"%f", cam.py)
        printf(c" size ")
        printf(c"%f", cam.sx)
        printf(c" ")
        printf(c"%f\n", cam.sy)
    end
    i::Int32 = Int32(0)
    while i < scene.entity_count
        e::SceneEntity = unsafe_load(elem_ptr(scene.entities, i))
        printf(c"entity ")
        print_span(scene, e.name)
        printf(c" id ")
        print_span(scene, e.id)
        printf(c" active ")
        printf(c"%d", e.is_active)
        printf(c" parent ")
        printf(c"%d\n", e.parent_index)
        if e.transform >= Int32(0)
            t::SceneTransform = unsafe_load(elem_ptr(scene.transforms, e.transform))
            printf(c"  transform ")
            printf(c"%f", t.px)
            printf(c" ")
            printf(c"%f\n", t.py)
        end
        if e.sprite >= Int32(0)
            s::SceneSprite = unsafe_load(elem_ptr(scene.sprites, e.sprite))
            printf(c"  sprite ")
            print_span(scene, s.image)
            printf(c"\n")
        end
        if e.collider >= Int32(0)
            col::SceneCollider = unsafe_load(elem_ptr(scene.colliders, e.collider))
            printf(c"  collider ")
            print_span(scene, col.tag)
            printf(c"\n")
        end
        if e.rigidbody >= Int32(0)
            body::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, e.rigidbody))
            printf(c"  rigidbody mass ")
            printf(c"%f\n", body.mass)
        end
        if e.sound >= Int32(0)
            snd::SceneSound = unsafe_load(elem_ptr(scene.sounds, e.sound))
            printf(c"  sound ")
            print_span(scene, snd.path)
            printf(c"\n")
        end
        if e.shape >= Int32(0)
            printf(c"  shape\n")
        end
        if e.animator >= Int32(0)
            anim::SceneAnimator = unsafe_load(elem_ptr(scene.animators, e.animator))
            printf(c"  animator ")
            printf(c"%d\n", anim.anim_count)
        end
        i += Int32(1)
    end
    u::Int32 = Int32(0)
    while u < scene.ui_count
        item::SceneUI = unsafe_load(elem_ptr(scene.ui, u))
        printf(c"ui ")
        print_span(scene, item.kind)
        printf(c" ")
        print_span(scene, item.name)
        printf(c" text ")
        print_span(scene, item.text)
        printf(c"\n")
        u += Int32(1)
    end
    return
end

function reset_counts!(scene::Ptr{Scene})
    scene.entity_count = Int32(0)
    scene.transform_count = Int32(0)
    scene.sprite_count = Int32(0)
    scene.collider_count = Int32(0)
    scene.rigidbody_count = Int32(0)
    scene.sound_count = Int32(0)
    scene.shape_count = Int32(0)
    scene.animator_count = Int32(0)
    scene.animation_count = Int32(0)
    scene.frame_count = Int32(0)
    scene.ui_count = Int32(0)
    return
end

function scene_slot(do_set::Int32, value::UInt64)::UInt64
    return Base.llvmcall(("""
        @g_scene = global i64 0
        define i64 @main(i32 %do_set, i64 %value) {
        entry:
            %set = icmp ne i32 %do_set, 0
            br i1 %set, label %write, label %read
        write:
            store i64 %value, i64* @g_scene
            ret i64 %value
        read:
            %v = load i64, i64* @g_scene
            ret i64 %v
        }
    """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end

function llvm_set_scene(scene::Ptr{Scene})
    handle::UInt64 = reinterpret(UInt64, scene)
    Base.llvmcall(("""
        declare i64 @scene_slot(i32, i64) nounwind
        define void @main(i64 %value) {
        entry:
            call i64 @scene_slot(i32 1, i64 %value)
            ret void
        }
    """, "main"), Cvoid, Tuple{UInt64}, handle)
    return
end

function llvm_get_scene()::Ptr{Scene}
    handle::UInt64 = Base.llvmcall(("""
        declare i64 @scene_slot(i32, i64) nounwind
        define i64 @main() {
        entry:
            %r = call i64 @scene_slot(i32 0, i64 0)
            ret i64 %r
        }
    """, "main"), UInt64, Tuple{},)
    return reinterpret(Ptr{Scene}, handle)
end

function llvm_load_scene(path::Ptr{UInt8})::Ptr{Scene}
    return Base.llvmcall(("""
        declare i8* @load_scene(i8*) nounwind
        define i8* @main(i8* %path) {
        entry:
            %r = call i8* @load_scene(i8* %path)
            ret i8* %r
        }
    """, "main"), Ptr{Scene}, Tuple{Ptr{UInt8}}, path)
end

function load_scene(path::Ptr{UInt8})::Ptr{Scene}
    file::FileBytes = read_file(path)
    if file.ptr == Ptr{UInt8}(C_NULL)
        return Ptr{Scene}(C_NULL)
    end
    arena::Ptr{Arena} = arena_create(SCENE_ARENA_BYTES)
    scratch_entity::Ptr{SceneEntity} = Ptr{SceneEntity}(wasm_malloc(UInt32(sizeof(SceneEntity))))
    scratch_fields::Ptr{CompFields} = Ptr{CompFields}(wasm_malloc(UInt32(sizeof(CompFields))))
    print_buf::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(UInt32(256)))
    scene::Ptr{Scene} = Ptr{Scene}(wasm_malloc(UInt32(sizeof(Scene))))
    if arena == Ptr{Arena}(C_NULL) || scratch_entity == Ptr{SceneEntity}(C_NULL) || scratch_fields == Ptr{CompFields}(C_NULL) || print_buf == Ptr{UInt8}(C_NULL) || scene == Ptr{Scene}(C_NULL)
        wasm_free(file.ptr)
        printf(c"scene alloc failed\n")
        return Ptr{Scene}(C_NULL)
    end
    none_ent::Ptr{SceneEntity} = Ptr{SceneEntity}(C_NULL)
    none_tr::Ptr{SceneTransform} = Ptr{SceneTransform}(C_NULL)
    none_sp::Ptr{SceneSprite} = Ptr{SceneSprite}(C_NULL)
    none_co::Ptr{SceneCollider} = Ptr{SceneCollider}(C_NULL)
    none_rb::Ptr{SceneRigidbody} = Ptr{SceneRigidbody}(C_NULL)
    none_so::Ptr{SceneSound} = Ptr{SceneSound}(C_NULL)
    none_sh::Ptr{SceneShape} = Ptr{SceneShape}(C_NULL)
    none_an::Ptr{SceneAnimator} = Ptr{SceneAnimator}(C_NULL)
    none_aa::Ptr{SceneAnimation} = Ptr{SceneAnimation}(C_NULL)
    none_fr::Ptr{SceneFrame} = Ptr{SceneFrame}(C_NULL)
    none_ui::Ptr{SceneUI} = Ptr{SceneUI}(C_NULL)
    unsafe_store!(scene, Scene(
        file.ptr, file.len, arena,
        none_ent, Int32(0),
        none_tr, Int32(0),
        none_sp, Int32(0),
        none_co, Int32(0),
        none_rb, Int32(0),
        none_so, Int32(0),
        none_sh, Int32(0),
        none_an, Int32(0),
        none_aa, Int32(0),
        none_fr, Int32(0),
        none_ui, Int32(0),
        blank_camera(),
        print_buf, scratch_entity, scratch_fields,
    ))
    cursor::Ptr{JsonCursor} = Ptr{JsonCursor}(wasm_malloc(UInt32(sizeof(JsonCursor))))
    unsafe_store!(cursor, JsonCursor(file.ptr, file.len, UInt32(0)))
    read_root!(scene, cursor, MODE_COUNT)
    n_ent::Int32 = scene.entity_count
    n_tr::Int32 = scene.transform_count
    n_sp::Int32 = scene.sprite_count
    n_co::Int32 = scene.collider_count
    n_rb::Int32 = scene.rigidbody_count
    n_so::Int32 = scene.sound_count
    n_sh::Int32 = scene.shape_count
    n_an::Int32 = scene.animator_count
    n_aa::Int32 = scene.animation_count
    n_fr::Int32 = scene.frame_count
    n_ui::Int32 = scene.ui_count
    scene.arena.used = UInt32(0)
    scene.entities = arena_array(scene.arena, SceneEntity, n_ent)
    scene.transforms = arena_array(scene.arena, SceneTransform, n_tr)
    scene.sprites = arena_array(scene.arena, SceneSprite, n_sp)
    scene.colliders = arena_array(scene.arena, SceneCollider, n_co)
    scene.rigidbodies = arena_array(scene.arena, SceneRigidbody, n_rb)
    scene.sounds = arena_array(scene.arena, SceneSound, n_so)
    scene.shapes = arena_array(scene.arena, SceneShape, n_sh)
    scene.animators = arena_array(scene.arena, SceneAnimator, n_an)
    scene.animations = arena_array(scene.arena, SceneAnimation, n_aa)
    scene.frames = arena_array(scene.arena, SceneFrame, n_fr)
    scene.ui = arena_array(scene.arena, SceneUI, n_ui)
    reset_counts!(scene)
    cursor.pos = UInt32(0)
    read_root!(scene, cursor, MODE_FILL)
    wasm_free(Ptr{Cvoid}(cursor))
    resolve_parents!(scene)
    print_scene(scene)
    llvm_set_scene(scene)
    return scene
end
