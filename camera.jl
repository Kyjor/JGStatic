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
