# Impulse resolution for AABBs, from Randy Gaul's "Basics and Impulse Resolution".
# One integration, then a few contact iterations. Static colliders use inverse mass 0.

const GRAVITY = 9.81
const RESTITUTION = 0.0
const POSITION_PERCENT = 0.2
const POSITION_SLOP = 0.01
const SOLVE_ITERATIONS = Int32(4)

struct Manifold
    hit::Int32
    nx::Float64
    ny::Float64
    penetration::Float64
end

function store_velocity(scene::Ptr{Scene}, index::Int32, vx::Float64, vy::Float64)
    body::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, index))
    unsafe_store!(elem_ptr(scene.rigidbodies, index), SceneRigidbody(
        body.entity, body.mass, body.drag, body.use_gravity, vx, vy,
    ))
    return
end

function move_body(entity::SceneEntity, dx::Float64, dy::Float64)
    scene::Ptr{Scene} = llvm_get_scene()
    if entity.transform < Int32(0) || entity.transform >= scene.transform_count
        return
    end
    transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity.transform))
    _entity_set_position(entity, transform.px + dx, transform.py + dy)
    return
end

function aabb_manifold(
    ax::Float64, ay::Float64, aw::Float64, ah::Float64,
    bx::Float64, by::Float64, bw::Float64, bh::Float64,
)::Manifold
    none::Manifold = Manifold(Int32(0), 0.0, 0.0, 0.0)
    nx::Float64 = (bx + bw * 0.5) - (ax + aw * 0.5)
    ny::Float64 = (by + bh * 0.5) - (ay + ah * 0.5)
    x_overlap::Float64 = aw * 0.5 + bw * 0.5 - abs(nx)
    if x_overlap <= 0.0
        return none
    end
    y_overlap::Float64 = ah * 0.5 + bh * 0.5 - abs(ny)
    if y_overlap <= 0.0
        return none
    end
    if x_overlap < y_overlap
        if nx < 0.0
            return Manifold(Int32(1), -1.0, 0.0, x_overlap)
        end
        return Manifold(Int32(1), 1.0, 0.0, x_overlap)
    end
    if ny < 0.0
        return Manifold(Int32(1), 0.0, -1.0, y_overlap)
    end
    return Manifold(Int32(1), 0.0, 1.0, y_overlap)
end

function resolve_pair(
    scene::Ptr{Scene},
    entity_a::SceneEntity,
    body_a_index::Int32,
    ax::Float64, ay::Float64, aw::Float64, ah::Float64,
    entity_b::SceneEntity,
    bx::Float64, by::Float64, bw::Float64, bh::Float64,
)
    m::Manifold = aabb_manifold(ax, ay, aw, ah, bx, by, bw, bh)
    if m.hit == Int32(0)
        return
    end
    body_a::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, body_a_index))
    inv_a::Float64 = 0.0
    if body_a.mass > 0.0
        inv_a = 1.0 / body_a.mass
    end
    avx::Float64 = body_a.vx
    avy::Float64 = body_a.vy
    inv_b::Float64 = 0.0
    bvx::Float64 = 0.0
    bvy::Float64 = 0.0
    body_b_index::Int32 = entity_b.rigidbody
    has_b::Int32 = Int32(0)
    if body_b_index >= Int32(0) && body_b_index < scene.rigidbody_count
        body_b::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, body_b_index))
        bvx = body_b.vx
        bvy = body_b.vy
        if body_b.mass > 0.0
            inv_b = 1.0 / body_b.mass
            has_b = Int32(1)
        end
    end
    inv_sum::Float64 = inv_a + inv_b
    if inv_sum <= 0.0
        return
    end
    rvx::Float64 = bvx - avx
    rvy::Float64 = bvy - avy
    vel_n::Float64 = rvx * m.nx + rvy * m.ny
    if vel_n <= 0.0
        j::Float64 = -(1.0 + RESTITUTION) * vel_n / inv_sum
        ix::Float64 = j * m.nx
        iy::Float64 = j * m.ny
        store_velocity(scene, body_a_index, avx - inv_a * ix, avy - inv_a * iy)
        if has_b == Int32(1)
            store_velocity(scene, body_b_index, bvx + inv_b * ix, bvy + inv_b * iy)
        end
    end
    sunk::Float64 = m.penetration - POSITION_SLOP
    if sunk > 0.0
        corr::Float64 = sunk / inv_sum * POSITION_PERCENT
        move_body(entity_a, -inv_a * corr * m.nx, -inv_a * corr * m.ny)
        if has_b == Int32(1)
            move_body(entity_b, inv_b * corr * m.nx, inv_b * corr * m.ny)
        end
    end
    return
end

function integrate_body(scene::Ptr{Scene}, index::Int32, dt::Float64)
    body::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, index))
    if body.entity < Int32(0) || body.entity >= scene.entity_count
        return
    end
    entity::SceneEntity = unsafe_load(elem_ptr(scene.entities, body.entity))
    if entity.is_active == Int32(0) || entity.transform < Int32(0) || entity.transform >= scene.transform_count
        return
    end
    vx::Float64 = body.vx
    vy::Float64 = body.vy
    if body.use_gravity != Int32(0)
        vy += GRAVITY * dt
    end
    damp::Float64 = 1.0 - body.drag * dt
    if damp < 0.0
        damp = 0.0
    end
    vx *= damp
    vy *= damp
    store_velocity(scene, index, vx, vy)
    if body.mass > 0.0
        transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity.transform))
        _entity_set_position(entity, transform.px + vx * dt, transform.py + vy * dt)
    end
    return
end

function resolve_contacts(scene::Ptr{Scene})
    rigidbody_index::Int32 = Int32(0)
    while rigidbody_index < scene.rigidbody_count
        rigidbody::SceneRigidbody = unsafe_load(elem_ptr(scene.rigidbodies, rigidbody_index))
        if rigidbody.entity >= Int32(0) && rigidbody.entity < scene.entity_count && rigidbody.mass > 0.0
            entity_a::SceneEntity = unsafe_load(elem_ptr(scene.entities, rigidbody.entity))
            if entity_a.is_active != Int32(0) && entity_a.transform >= Int32(0) && entity_a.transform < scene.transform_count && entity_a.collider >= Int32(0) && entity_a.collider < scene.collider_count
                collider_a::SceneCollider = unsafe_load(elem_ptr(scene.colliders, entity_a.collider))
                if collider_a.enabled > Int32(0) && collider_a.is_trigger == Int32(0)
                    collider_index::Int32 = Int32(0)
                    while collider_index < scene.collider_count
                        collider_b::SceneCollider = unsafe_load(elem_ptr(scene.colliders, collider_index))
                        if collider_b.enabled > Int32(0) && collider_b.is_trigger == Int32(0) && collider_b.entity >= Int32(0) && collider_b.entity < scene.entity_count && collider_b.entity != rigidbody.entity
                            entity_b::SceneEntity = unsafe_load(elem_ptr(scene.entities, collider_b.entity))
                            if entity_b.is_active != Int32(0) && entity_b.transform >= Int32(0) && entity_b.transform < scene.transform_count && (entity_b.rigidbody < Int32(0) || entity_b.rigidbody > rigidbody_index)
                                transform_a::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity_a.transform))
                                transform_b::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity_b.transform))
                                resolve_pair(
                                    scene,
                                    entity_a,
                                    rigidbody_index,
                                    transform_a.px + collider_a.ox,
                                    transform_a.py + collider_a.oy,
                                    transform_a.sx * collider_a.width,
                                    transform_a.sy * collider_a.height,
                                    entity_b,
                                    transform_b.px + collider_b.ox,
                                    transform_b.py + collider_b.oy,
                                    transform_b.sx * collider_b.width,
                                    transform_b.sy * collider_b.height,
                                )
                            end
                        end
                        collider_index += Int32(1)
                    end
                end
            end
        end
        rigidbody_index += Int32(1)
    end
    return
end

function physics_step(dt::Float64)
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL)
        return
    end
    step::Float64 = dt
    if step > 0.05
        step = 0.05
    end
    if step < 0.0
        return
    end
    index::Int32 = Int32(0)
    while index < scene.rigidbody_count
        integrate_body(scene, index, step)
        index += Int32(1)
    end
    iter::Int32 = Int32(0)
    while iter < SOLVE_ITERATIONS
        resolve_contacts(scene)
        iter += Int32(1)
    end
    return
end

function entity_on_ground(index::Int32)::Int32
    scene::Ptr{Scene} = llvm_get_scene()
    if scene == Ptr{Scene}(C_NULL)
        return Int32(0)
    end
    entity::SceneEntity = get_entity(index)
    if entity.transform < Int32(0) || entity.transform >= scene.transform_count || entity.collider < Int32(0) || entity.collider >= scene.collider_count
        return Int32(0)
    end
    transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, entity.transform))
    collider::SceneCollider = unsafe_load(elem_ptr(scene.colliders, entity.collider))
    width::Float64 = transform.sx * collider.width
    feet::Float64 = transform.py + collider.oy + transform.sy * collider.height
    left::Float64 = transform.px + collider.ox + width * 0.15
    foot_w::Float64 = width * 0.7
    foot_h::Float64 = 0.08
    collider_index::Int32 = Int32(0)
    while collider_index < scene.collider_count
        other::SceneCollider = unsafe_load(elem_ptr(scene.colliders, collider_index))
        if other.enabled > Int32(0) && other.is_trigger == Int32(0) && other.entity >= Int32(0) && other.entity < scene.entity_count && other.entity != index
            other_entity::SceneEntity = unsafe_load(elem_ptr(scene.entities, other.entity))
            if other_entity.is_active != Int32(0) && other_entity.transform >= Int32(0) && other_entity.transform < scene.transform_count
                other_transform::SceneTransform = unsafe_load(elem_ptr(scene.transforms, other_entity.transform))
                hit::Manifold = aabb_manifold(
                    left, feet, foot_w, foot_h,
                    other_transform.px + other.ox,
                    other_transform.py + other.oy,
                    other_transform.sx * other.width,
                    other_transform.sy * other.height,
                )
                if hit.hit == Int32(1)
                    return Int32(1)
                end
            end
        end
        collider_index += Int32(1)
    end
    return Int32(0)
end
