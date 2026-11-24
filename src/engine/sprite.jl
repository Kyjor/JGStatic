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
    order::Ptr{Int32} = Ptr{Int32}(wasm_malloc(unsafe_trunc(UInt32, n) * UInt32(sizeof(Int32))))
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
    textures::Ptr{Ptr{SDL_Texture}} = Ptr{Ptr{SDL_Texture}}(wasm_malloc(unsafe_trunc(UInt32, n) * UInt32(sizeof(Ptr{SDL_Texture}))))
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
