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
            if entity_a_collider.enabled && entity_b_collider.enabled
                printf(c"Colliders\n")
            end

            collider_index += Int32(1)
        end

        rigidbody_index += Int32(1)
    end
end
