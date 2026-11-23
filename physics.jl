function check_collisions()
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL)
        printf(c"Scene is null\n")
        return
    end

    rigidbody_index::Int32 = Int32(0)
    while rigidbody_index < scene.rigidbody_count
        rigidbody::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, rigidbody_index))
        collider_index::Int32 = Int32(0)
        entity_a::SceneEntity = unsafe_load(elem_ptr(scene.entities, rigidbody.entity))
        entity_a_transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity_a.transform))
        entity_a_collider::SceneCollider = unsafe_load(elem_ptr(scene.colliders, entity_a.collider))
        while collider_index < scene.collider_count
            entity_b::SceneEntity = unsafe_load(elem_ptr(scene.entities, collider_index))
            entity_b_transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity_b.transform))
            entity_b_collider::SceneCollider = unsafe_load(elem_ptr(scene.colliders, entity_b.collider))
            if entity_a_collider.enabled  > Int32(0) && entity_b_collider.enabled > Int32(0) && entity_a_collider.entity != entity_b_collider.entity
                collision::Int32 = aabb_overlap(
                    entity_a_transform.px, entity_a_transform.py,
                    entity_a_collider.width, entity_a_collider.height,
                    entity_b_transform.px, entity_b_transform.py,
                    entity_b_collider.width, entity_b_collider.height,
                 )

                 if collision == Int32(1)
                    printf(c"Colliding")
                 end
            end

            collider_index += Int32(1)
        end

        rigidbody_index += Int32(1)
    end
end

function aabb_overlap(
    a_position_x, a_position_y, a_collider_width, a_collider_height,
    b_position_x, b_position_y, b_collider_width, b_collider_height
)::Int32
    if  (a_position_x < b_position_x + b_collider_width) &&
        (a_position_x + a_collider_width > b_position_x) &&
        (a_position_y < b_position_y + b_collider_height) &&
        (a_position_y + a_collider_height > b_position_y)
            return Int32(1)
    end

    return Int32(0)
end

function resolve_aabb()
end