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
                    printf(c"Colliding\n")
                    resolve_aabb(
                        entity_a,
                        entity_a_transform.px, entity_a_transform.py,
                        entity_a_collider.width, entity_a_collider.height,
                        entity_b_transform.px, entity_b_transform.py,
                        entity_b_collider.width, entity_b_collider.height,
                    )
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

function resolve_aabb(
    entity_a::SceneEntity,
    a_position_x, a_position_y, a_collider_width, a_collider_height,
    b_position_x, b_position_y, b_collider_width, b_collider_height
)
    overlap_left   = (a_position_x + a_collider_width) - b_position_x; # A's right past B's left
     overlap_right  = (b_position_x + b_collider_width) - a_position_x; # B's right past A's left
     overlap_top    = (a_position_y + a_collider_height) - b_position_y; # A's bottom past B's top
     overlap_bottom = (b_position_y + b_collider_height) - a_position_y; # B's bottom past A's top

     min_x = overlap_left < overlap_right ? -overlap_left : overlap_right;
     min_y = overlap_top < overlap_bottom ? -overlap_top : overlap_bottom;

    if (abs(min_x) < abs(min_y))
        a_position_x += min_x;
    else
        a_position_y += min_y;
    end
    _entity_set_position(entity_a, a_position_x, a_position_y)

end