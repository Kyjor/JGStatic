# Calls into game code defined in host.c (linked at build time).

function llvm_game_load()
    Base.llvmcall(("""
                   declare void @game_load() nounwind

                   define void @main() {
                       entry:
                       call void @game_load()
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{},)
end

function llvm_game_late_update()
    Base.llvmcall(("""
                   declare void @game_late_update() nounwind

                   define void @main() {
                       entry:
                       call void @game_late_update()
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{},)
end

function llvm_game_update(dt::Float64)
    Base.llvmcall(("""
                   declare void @game_update(double) nounwind

                   define void @main(double %dt) {
                       entry:
                       call void @game_update(double %dt)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{Float64}, dt)
end

function llvm_game_key_pressed(key::Int32)
    Base.llvmcall(("""
                   declare void @game_key_pressed(i32) nounwind

                   define void @main(i32 %key) {
                       entry:
                       call void @game_key_pressed(i32 %key)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{Int32}, key)
end

function llvm_game_key_released(key::Int32)
    Base.llvmcall(("""
                   declare void @game_key_released(i32) nounwind

                   define void @main(i32 %key) {
                       entry:
                       call void @game_key_released(i32 %key)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{Int32}, key)
end

function llvm_game_draw()
    Base.llvmcall(("""
                   declare void @game_draw() nounwind

                   define void @main() {
                       entry:
                       call void @game_draw()
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{},)
end

function llvm_game_should_continue()::Int32
    Base.llvmcall(("""
                   declare i32 @game_should_continue() nounwind

                   define i32 @main() {
                       entry:
                       %r = call i32 @game_should_continue()
                       ret i32 %r
                       }
                       """, "main"), Int32, Tuple{},)
end

function llvm_game_scene_load()
    Base.llvmcall(("""
                   declare void @game_scene_load() nounwind

                   define void @main() {
                       entry:
                       call void @game_scene_load()
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{},)
end

function llvm_game_wants_3d()::Int32
    Base.llvmcall(("""
                   declare i32 @game_wants_3d() nounwind

                   define i32 @main() {
                       entry:
                       %r = call i32 @game_wants_3d()
                       ret i32 %r
                       }
                       """, "main"), Int32, Tuple{},)
end

function llvm_game_model_yaw()::Float64
    Base.llvmcall(("""
                   declare double @game_model_yaw() nounwind

                   define double @main() {
                       entry:
                       %r = call double @game_model_yaw()
                       ret double %r
                       }
                       """, "main"), Float64, Tuple{},)
end

function llvm_game_cam_x()::Float64
    Base.llvmcall(("""
                   declare double @game_cam_x() nounwind
                   define double @main() {
                       entry:
                       %r = call double @game_cam_x()
                       ret double %r
                       }
                       """, "main"), Float64, Tuple{},)
end

function llvm_game_cam_y()::Float64
    Base.llvmcall(("""
                   declare double @game_cam_y() nounwind
                   define double @main() {
                       entry:
                       %r = call double @game_cam_y()
                       ret double %r
                       }
                       """, "main"), Float64, Tuple{},)
end

function llvm_game_cam_z()::Float64
    Base.llvmcall(("""
                   declare double @game_cam_z() nounwind
                   define double @main() {
                       entry:
                       %r = call double @game_cam_z()
                       ret double %r
                       }
                       """, "main"), Float64, Tuple{},)
end

function llvm_game_cam_yaw()::Float64
    Base.llvmcall(("""
                   declare double @game_cam_yaw() nounwind
                   define double @main() {
                       entry:
                       %r = call double @game_cam_yaw()
                       ret double %r
                       }
                       """, "main"), Float64, Tuple{},)
end

function llvm_game_cam_pitch()::Float64
    Base.llvmcall(("""
                   declare double @game_cam_pitch() nounwind
                   define double @main() {
                       entry:
                       %r = call double @game_cam_pitch()
                       ret double %r
                       }
                       """, "main"), Float64, Tuple{},)
end

function llvm_game_consume_shot()::Int32
    Base.llvmcall(("""
                   declare i32 @game_consume_shot() nounwind
                   define i32 @main() {
                       entry:
                       %r = call i32 @game_consume_shot()
                       ret i32 %r
                       }
                       """, "main"), Int32, Tuple{},)
end

function llvm_game_mouse_moved(dx::Int32, dy::Int32)
    Base.llvmcall(("""
                   declare void @game_mouse_moved(i32, i32) nounwind
                   define void @main(i32 %dx, i32 %dy) {
                       entry:
                       call void @game_mouse_moved(i32 %dx, i32 %dy)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{Int32, Int32}, dx, dy)
end

function llvm_game_mouse_pressed(button::Int32)
    Base.llvmcall(("""
                   declare void @game_mouse_pressed(i32) nounwind
                   define void @main(i32 %button) {
                       entry:
                       call void @game_mouse_pressed(i32 %button)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{Int32}, button)
end

function llvm_game_shutdown()
    Base.llvmcall(("""
                   declare void @game_shutdown() nounwind

                   define void @main() {
                       entry:
                       call void @game_shutdown()
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{},)
end
