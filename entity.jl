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
