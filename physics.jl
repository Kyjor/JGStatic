function check_collisions()
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL)
        printf(c"Scene is null\n")
        return
    end

    i::Int32 = Int32(0)
    while i < scene.rigidbody_count
        rigidbody::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, i))
        if rigidbody.entity > Int32(0)
            printf(c"Scene rigidody collisions %d \n", rigidbody.entity)
        end

        i += Int32(1)
    end
end
