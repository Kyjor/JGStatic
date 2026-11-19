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
        end
    end
    wasm_free(Ptr{Cvoid}(event_ptr))
    return quit
end

function delay()
    llvm_SDL_Delay(UInt32(16))
    return
end

function color_u8(value::Int32)::UInt8
    if value <= Int32(0)
        return UInt8(0)
    end
    if value >= Int32(255)
        return UInt8(255)
    end
    return unsafe_trunc(UInt8, value)
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

# entities
# colliders
# sprites
function game_loop()
    p::Ptr{Int32} = Ptr{Int32}(wasm_malloc(UInt32(4)))
    unsafe_store!(p, Int32(42))
    printf(unsafe_load(p))

    load()
    llvm_game_load()
    init()
    open_window(str_ptr(w"Test"))
    prepare_sprites()

    exit::Int32 = Int32(0)
    while exit == Int32(0)
        render_clear()
        exit = poll_events()
        llvm_game_update()
        draw()
        llvm_game_draw()

        render_present()
        delay()
    end

    llvm_game_shutdown()
end

const SCALE_UNITS = 64.0
const PIXELS_PER_UNIT = 16.0

function span_c_string(span::ByteSpan)::Ptr{UInt8}
    if span.ptr == Ptr{UInt8}(C_NULL) || span.len == UInt32(0)
        return Ptr{UInt8}(C_NULL)
    end
    buf::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(span.len + UInt32(1)))
    i::UInt32 = UInt32(0)
    while i < span.len
        unsafe_store!(buf + Int(i), unsafe_load(span.ptr + Int(i)))
        i += UInt32(1)
    end
    unsafe_store!(buf + Int(span.len), UInt8(0))
    return buf
end

function frac01(value::Float64)::Float64
    return value - Float64(unsafe_trunc(Int64, value))
end

function find_sprite_texture(scene::Ptr{Scene}, image::ByteSpan)::Ptr{SDL_Texture}
    i::Int32 = Int32(0)
    while i < scene.sprite_count
        other::SceneSprite = unsafe_load(elem_ptr(scene.sprites, i))
        if spans_eq(image, other.image) == Int32(1)
            tex::Ptr{SDL_Texture} = unsafe_load(elem_ptr(scene.textures, i))
            if tex != Ptr{SDL_Texture}(C_NULL)
                return tex
            end
        end
        i += Int32(1)
    end
    return Ptr{SDL_Texture}(C_NULL)
end

function build_draw_order(scene::Ptr{Scene})
    n::Int32 = scene.sprite_count
    if n <= Int32(0)
        return
    end
    order::Ptr{Int32} = Ptr{Int32}(wasm_malloc(UInt32(n) * UInt32(sizeof(Int32))))
    if order == Ptr{Int32}(C_NULL)
        return
    end
    i::Int32 = Int32(0)
    while i < n
        unsafe_store!(elem_ptr(order, i), i)
        i += Int32(1)
    end
    i = Int32(1)
    while i < n
        key::Int32 = unsafe_load(elem_ptr(order, i))
        key_sprite::SceneSprite = unsafe_load(elem_ptr(scene.sprites, key))
        key_layer::Int32 = key_sprite.layer
        j::Int32 = i - Int32(1)
        while j >= Int32(0)
            other::Int32 = unsafe_load(elem_ptr(order, j))
            other_sprite::SceneSprite = unsafe_load(elem_ptr(scene.sprites, other))
            if other_sprite.layer <= key_layer
                break
            end
            unsafe_store!(elem_ptr(order, j + Int32(1)), other)
            j -= Int32(1)
        end
        unsafe_store!(elem_ptr(order, j + Int32(1)), key)
        i += Int32(1)
    end
    scene.draw_order = order
    return
end

function prepare_sprites()
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL) || scene.sprite_count <= Int32(0)
        return
    end
    renderer::Ptr{SDL_Renderer} = llvm_get_renderer()
    if renderer == Ptr{SDL_Renderer}(C_NULL)
        return
    end
    n::Int32 = scene.sprite_count
    textures::Ptr{Ptr{SDL_Texture}} = Ptr{Ptr{SDL_Texture}}(wasm_malloc(UInt32(n) * UInt32(sizeof(Ptr{SDL_Texture}))))
    src_rect::Ptr{SDL_Rect} = Ptr{SDL_Rect}(wasm_malloc(UInt32(sizeof(SDL_Rect))))
    dst_rect::Ptr{SDL_FRect} = Ptr{SDL_FRect}(wasm_malloc(UInt32(sizeof(SDL_FRect))))
    rot_center::Ptr{SDL_FPoint} = Ptr{SDL_FPoint}(wasm_malloc(UInt32(sizeof(SDL_FPoint))))
    if textures == Ptr{Ptr{SDL_Texture}}(C_NULL) || src_rect == Ptr{SDL_Rect}(C_NULL) || dst_rect == Ptr{SDL_FRect}(C_NULL) || rot_center == Ptr{SDL_FPoint}(C_NULL)
        printf(c"sprite alloc failed\n")
        return
    end
    scene.textures = textures
    scene.src_rect = src_rect
    scene.dst_rect = dst_rect
    scene.rot_center = rot_center
    i::Int32 = Int32(0)
    while i < n
        unsafe_store!(elem_ptr(textures, i), Ptr{SDL_Texture}(C_NULL))
        i += Int32(1)
    end
    base::Ptr{UInt8} = str_ptr(w".")
    i = Int32(0)
    while i < n
        sprite::SceneSprite = unsafe_load(elem_ptr(scene.sprites, i))
        tex::Ptr{SDL_Texture} = find_sprite_texture(scene, sprite.image)
        if tex == Ptr{SDL_Texture}(C_NULL)
            file::Ptr{UInt8} = span_c_string(sprite.image)
            if file != Ptr{UInt8}(C_NULL)
                full::Ptr{UInt8} = malloc_joined_path(base, file, ASSETS_IMAGES_INFIX)
                wasm_free(file)
                if full != Ptr{UInt8}(C_NULL)
                    tex = llvm_IMG_LoadTexture(renderer, full)
                    if tex == Ptr{SDL_Texture}(C_NULL)
                        printf(c"sprite load failed %s\n", full)
                    else
                        llvm_SDL_SetTextureBlendMode(tex, UInt32(1))
                    end
                    wasm_free(full)
                end
            end
        end
        unsafe_store!(elem_ptr(textures, i), tex)
        i += Int32(1)
    end
    wasm_free(base)
    build_draw_order(scene)
    return
end

function camera_move(dx::Float64, dy::Float64)
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL)
        return
    end
    cam::SceneCamera = scene.camera
    scene.camera = SceneCamera(
        cam.present,
        cam.px + dx,
        cam.py + dy,
        cam.sx, cam.sy, cam.ox, cam.oy, cam.zoom,
        cam.br, cam.bg, cam.bb, cam.ba,
    )
    return
end

function camera_set_position(x::Float64, y::Float64)
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL)
        return
    end
    cam::SceneCamera = scene.camera
    scene.camera = SceneCamera(
        cam.present,
        x, y, cam.sx, cam.sy, cam.ox, cam.oy, cam.zoom,
        cam.br, cam.bg, cam.bb, cam.ba,
    )
    return
end

function draw_sprite(
    renderer::Ptr{SDL_Renderer},
    scene::Ptr{Scene},
    sprite::SceneSprite,
    transform::SceneTransform,
    texture::Ptr{SDL_Texture},
)
    cam::SceneCamera = scene.camera
    zoom::Float64 = cam.zoom
    if zoom == 0.0
        zoom = 1.0
    end
    pixels::Float64 = SCALE_UNITS * zoom
    cam_x::Float64 = 0.0
    cam_y::Float64 = 0.0
    if cam.present == Int32(1)
        cam_x = (cam.px + cam.ox) * pixels
        cam_y = (cam.py + cam.oy) * pixels
    end
    adjusted_x::Float64 = (transform.px + sprite.ox) * pixels - cam_x
    adjusted_y::Float64 = (transform.py + sprite.oy) * pixels - cam_y
    crop_w::Float64 = sprite.width
    crop_h::Float64 = sprite.height
    source::Ptr{SDL_Rect} = Ptr{SDL_Rect}(C_NULL)
    if sprite.has_crop != Int32(0) && sprite.cropz > 0.0 && sprite.cropt > 0.0
        crop_w = sprite.cropz
        crop_h = sprite.cropt
        unsafe_store!(scene.src_rect, SDL_Rect(f64_to_i32(sprite.cropx), f64_to_i32(sprite.cropy), f64_to_i32(sprite.cropz), f64_to_i32(sprite.cropt)))
        source = scene.src_rect
    end
    scaled_w::Float64 = 0.0
    scaled_h::Float64 = 0.0
    if sprite.pixels_per_unit == Int32(0)
        scaled_w = crop_w * transform.sx * pixels / SCALE_UNITS
        scaled_h = crop_h * transform.sy * pixels / SCALE_UNITS
    else
        ppu::Float64 = Float64(sprite.pixels_per_unit)
        if sprite.pixels_per_unit < Int32(0)
            ppu = PIXELS_PER_UNIT
        end
        factor::Float64 = pixels / ppu
        scaled_w = crop_w * factor * transform.sx
        scaled_h = crop_h * factor * transform.sy
    end
    # Default anchor is center, same as JulGame.
    centered_x::Float64 = adjusted_x - (scaled_w - pixels * transform.sx) * 0.5
    centered_y::Float64 = adjusted_y - (scaled_h - pixels * transform.sy) * 0.5
    unsafe_store!(scene.dst_rect, SDL_FRect(Float32(centered_x), Float32(centered_y), Float32(scaled_w), Float32(scaled_h)))
    unsafe_store!(scene.rot_center, SDL_FPoint(Float32(scaled_w * frac01(sprite.cx)), Float32(scaled_h * frac01(sprite.cy))))
    llvm_SDL_SetTextureColorMod(texture, color_u8(sprite.red), color_u8(sprite.green), color_u8(sprite.blue))
    llvm_SDL_SetTextureAlphaMod(texture, color_u8(sprite.color_a))
    flip::UInt32 = UInt32(0)
    if sprite.is_flipped != Int32(0)
        flip = UInt32(1)
    end
    llvm_SDL_RenderCopyExF(renderer, texture, source, scene.dst_rect, sprite.rotation, scene.rot_center, flip)
    return
end

function draw()
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL) || scene.draw_order == Ptr{Int32}(C_NULL)
        return
    end
    renderer::Ptr{SDL_Renderer} = llvm_get_renderer()
    if renderer == Ptr{SDL_Renderer}(C_NULL)
        return
    end
    i::Int32 = Int32(0)
    while i < scene.sprite_count
        sprite_index::Int32 = unsafe_load(elem_ptr(scene.draw_order, i))
        sprite::SceneSprite = unsafe_load(elem_ptr(scene.sprites, sprite_index))
        texture::Ptr{SDL_Texture} = unsafe_load(elem_ptr(scene.textures, sprite_index))
        if texture != Ptr{SDL_Texture}(C_NULL) && sprite.entity >= Int32(0)
            entity::SceneEntity = unsafe_load(elem_ptr(scene.entities, sprite.entity))
            if entity.is_active != Int32(0) && entity.transform >= Int32(0)
                transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity.transform))
                draw_sprite(renderer, scene, sprite, transform, texture)
            end
        end
        i += Int32(1)
    end
    return
end

function get_entity(index::Int32)::SceneEntity
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL) || scene.entities == Ptr{SceneEntity}(C_NULL) || index < Int32(0) || index >= scene.entity_count
        return blank_entity()
    end
    return unsafe_load(elem_ptr(scene.entities, index))
end

function get_entity_position_x(index::Int32)::Float64
    entity::SceneEntity = get_entity(index)
    if entity.is_active == Int32(0) || entity.transform < Int32(0)
        return 0.0
    end
    scene::Ptr{Scene} = llvm_get_scene()
    return unsafe_load(elem_ptr(scene.transforms, entity.transform)).px
end

function get_entity_position_y(index::Int32)::Float64
    entity::SceneEntity = get_entity(index)
    if entity.is_active == Int32(0) || entity.transform < Int32(0)
        return 0.0
    end
    scene::Ptr{Scene} = llvm_get_scene()
    return unsafe_load(elem_ptr(scene.transforms, entity.transform)).py
end

function set_entity_position(index::Int32, x::Float64, y::Float64)
    entity::SceneEntity = get_entity(index)
    if entity.is_active == Int32(0) || entity.transform < Int32(0)
        return
    end
    scene::Ptr{Scene} = llvm_get_scene()
    if scene.transforms == Ptr{SceneTransform}(C_NULL) || entity.transform >= scene.transform_count
        return
    end
    transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity.transform))
    unsafe_store!(elem_ptr(scene.transforms, entity.transform), SceneTransform(
        transform.entity,
        x, y, transform.pz, transform.sx, transform.sy, transform.sz,
    ))
    return
end

function entity_move(index::Int32, dx::Float64, dy::Float64)
    entity::SceneEntity = get_entity(index)
    if entity.is_active == Int32(0) || entity.transform < Int32(0)
        return
    end
    scene::Ptr{Scene} = llvm_get_scene()
    if scene.transforms == Ptr{SceneTransform}(C_NULL) || entity.transform >= scene.transform_count
        return
    end
    transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity.transform))
    unsafe_store!(elem_ptr(scene.transforms, entity.transform), SceneTransform(
        transform.entity,
        transform.px + dx,
        transform.py + dy,
        transform.pz,
        transform.sx,
        transform.sy,
        transform.sz,
    ))
    return
end

function load()
    path::Ptr{UInt8} = str_ptr(w"scenes/scene.json")
    scene::Ptr{Scene} = llvm_load_scene(path)
    wasm_free(path)
    if scene == Ptr{Scene}(C_NULL)
        printf(c"scene load failed\n")
    end
    return
end

function jq_quit()::Bool



    return true
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
