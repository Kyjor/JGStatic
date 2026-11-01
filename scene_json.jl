# Byte cursor over a JSON buffer. Strings are slices of that buffer, not Julia Strings.

struct ByteSpan
    ptr::Ptr{UInt8}
    len::UInt32
end

struct JsonCursor
    bytes::Ptr{UInt8}
    length::UInt32
    pos::UInt32
end

struct KeyStep
    status::Int32 # 1 = key ready, 0 = object ended, -1 = error
    key::ByteSpan
end

function blank_span()::ByteSpan
    return ByteSpan(Ptr{UInt8}(C_NULL), UInt32(0))
end

macro k_str(s)
    bytes = Tuple(codeunits(String(s)))
    Expr(:call, :Val, Expr(:tuple, bytes...))
end

@generated function key_is(span::ByteSpan, ::Val{bytes})::Int32 where {bytes}
    body = Expr(:block)
    push!(body.args, :(span.len == $(UInt32(length(bytes))) || return Int32(0)))
    for (i, b) in enumerate(bytes)
        push!(body.args, :(unsafe_load(span.ptr + $(i - 1)) == $(UInt8(b)) || return Int32(0)))
    end
    push!(body.args, :(return Int32(1)))
    return body
end

function peek(c::Ptr{JsonCursor})::UInt8
    pos::UInt32 = c.pos
    if pos >= c.length
        return UInt8(0)
    end
    return unsafe_load(c.bytes + Int(pos))
end

function bump!(c::Ptr{JsonCursor})
    c.pos = c.pos + UInt32(1)
    return
end

function skip_ws!(c::Ptr{JsonCursor})
    while true
        b::UInt8 = peek(c)
        if b != UInt8(' ') && b != UInt8('\t') && b != UInt8('\n') && b != UInt8('\r')
            return
        end
        bump!(c)
    end
end

function scan_string!(c::Ptr{JsonCursor})::ByteSpan
    skip_ws!(c)
    if peek(c) != UInt8('"')
        return blank_span()
    end
    bump!(c)
    start::UInt32 = c.pos
    bytes::Ptr{UInt8} = c.bytes
    while c.pos < c.length
        b::UInt8 = unsafe_load(bytes + Int(c.pos))
        if b == UInt8('\\')
            c.pos = c.pos + UInt32(2)
            continue
        end
        if b == UInt8('"')
            len::UInt32 = c.pos - start
            bump!(c)
            return ByteSpan(bytes + Int(start), len)
        end
        bump!(c)
    end
    return blank_span()
end

function skip_number!(c::Ptr{JsonCursor})
    b::UInt8 = peek(c)
    if b == UInt8('-') || b == UInt8('+')
        bump!(c)
    end
    while true
        b = peek(c)
        if (b >= UInt8('0') && b <= UInt8('9')) || b == UInt8('.') || b == UInt8('e') || b == UInt8('E') || b == UInt8('+') || b == UInt8('-')
            bump!(c)
            continue
        end
        return
    end
end

function begin_container!(c::Ptr{JsonCursor}, open::UInt8)::Int32
    skip_ws!(c)
    if peek(c) != open
        return Int32(-1)
    end
    bump!(c)
    return Int32(0)
end

function next_key!(c::Ptr{JsonCursor})::KeyStep
    empty::ByteSpan = blank_span()
    skip_ws!(c)
    b::UInt8 = peek(c)
    if b == UInt8('}')
        bump!(c)
        return KeyStep(Int32(0), empty)
    end
    if b == UInt8(',')
        bump!(c)
        skip_ws!(c)
        b = peek(c)
    end
    if b == UInt8('}')
        bump!(c)
        return KeyStep(Int32(0), empty)
    end
    if b != UInt8('"')
        return KeyStep(Int32(-1), empty)
    end
    key::ByteSpan = scan_string!(c)
    skip_ws!(c)
    if peek(c) != UInt8(':')
        return KeyStep(Int32(-1), empty)
    end
    bump!(c)
    return KeyStep(Int32(1), key)
end

function next_element!(c::Ptr{JsonCursor})::Int32
    skip_ws!(c)
    b::UInt8 = peek(c)
    if b == UInt8(']')
        bump!(c)
        return Int32(0)
    end
    if b == UInt8(',')
        bump!(c)
        skip_ws!(c)
        b = peek(c)
        if b == UInt8(']')
            bump!(c)
            return Int32(0)
        end
    end
    if b == UInt8(0)
        return Int32(-1)
    end
    return Int32(1)
end

function skip_value!(c::Ptr{JsonCursor})::Int32
    before::UInt32 = c.pos
    skip_ws!(c)
    b::UInt8 = peek(c)
    status::Int32 = Int32(0)
    if b == UInt8('"')
        scan_string!(c)
    elseif b == UInt8('{')
        status = skip_object!(c)
    elseif b == UInt8('[')
        status = skip_array!(c)
    elseif b == UInt8('t')
        c.pos = c.pos + UInt32(4)
    elseif b == UInt8('f')
        c.pos = c.pos + UInt32(5)
    elseif b == UInt8('n')
        c.pos = c.pos + UInt32(4)
    elseif b == UInt8(0)
        return Int32(-1)
    else
        skip_number!(c)
    end
    if c.pos == before
        bump!(c)
        return Int32(-1)
    end
    return status
end

function skip_object!(c::Ptr{JsonCursor})::Int32
    if begin_container!(c, UInt8('{')) != Int32(0)
        return Int32(-1)
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            if step.status == Int32(0)
                return Int32(0)
            end
            return Int32(-1)
        end
        skip_value!(c)
    end
end

function skip_array!(c::Ptr{JsonCursor})::Int32
    if begin_container!(c, UInt8('[')) != Int32(0)
        return Int32(-1)
    end
    while true
        step::Int32 = next_element!(c)
        if step != Int32(1)
            if step == Int32(0)
                return Int32(0)
            end
            return Int32(-1)
        end
        skip_value!(c)
    end
end

function read_number!(c::Ptr{JsonCursor})::Float64
    skip_ws!(c)
    if peek(c) == UInt8('n')
        c.pos = c.pos + UInt32(4)
        return 0.0
    end
    sign::Float64 = 1.0
    if peek(c) == UInt8('-')
        sign = -1.0
        bump!(c)
    elseif peek(c) == UInt8('+')
        bump!(c)
    end
    value::Float64 = 0.0
    while true
        b::UInt8 = peek(c)
        if b < UInt8('0') || b > UInt8('9')
            break
        end
        value = value * 10.0 + Float64(b - UInt8('0'))
        bump!(c)
    end
    if peek(c) == UInt8('.')
        bump!(c)
        place::Float64 = 0.1
        while true
            b = peek(c)
            if b < UInt8('0') || b > UInt8('9')
                break
            end
            value = value + Float64(b - UInt8('0')) * place
            place = place * 0.1
            bump!(c)
        end
    end
    if peek(c) == UInt8('e') || peek(c) == UInt8('E')
        bump!(c)
        exp_sign::Int32 = Int32(1)
        if peek(c) == UInt8('-')
            exp_sign = Int32(-1)
            bump!(c)
        elseif peek(c) == UInt8('+')
            bump!(c)
        end
        exp_v::Int32 = Int32(0)
        while true
            b = peek(c)
            if b < UInt8('0') || b > UInt8('9')
                break
            end
            exp_v = exp_v * Int32(10) + Int32(b - UInt8('0'))
            bump!(c)
        end
        scale::Float64 = 1.0
        i::Int32 = Int32(0)
        if exp_v > Int32(40)
            exp_v = Int32(40)
        end
        if exp_sign > Int32(0)
            while i < exp_v
                scale = scale * 10.0
                i += Int32(1)
            end
        else
            while i < exp_v
                scale = scale * 0.1
                i += Int32(1)
            end
        end
        value = value * scale
    end
    return sign * value
end

function read_bool!(c::Ptr{JsonCursor})::Int32
    skip_ws!(c)
    b::UInt8 = peek(c)
    if b == UInt8('t')
        c.pos = c.pos + UInt32(4)
        return Int32(1)
    end
    if b == UInt8('f')
        c.pos = c.pos + UInt32(5)
        return Int32(0)
    end
    skip_value!(c)
    return Int32(0)
end

function f64_to_i32(x::Float64)::Int32
    if x >= 0.0
        return unsafe_trunc(Int32, x + 0.5)
    end
    return unsafe_trunc(Int32, x - 0.5)
end

struct SceneVec3
    x::Float64
    y::Float64
    z::Float64
end

struct SceneVec4
    x::Float64
    y::Float64
    z::Float64
    t::Float64
end

struct SceneColor
    r::Int32
    g::Int32
    b::Int32
    a::Int32
end

function read_vec2!(c::Ptr{JsonCursor}, x0::Float64, y0::Float64)::Vector2f
    x::Float64 = x0
    y::Float64 = y0
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return Vector2f(x, y)
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        if key_is(step.key, k"x") == Int32(1)
            x = read_number!(c)
        elseif key_is(step.key, k"y") == Int32(1)
            y = read_number!(c)
        else
            skip_value!(c)
        end
    end
    return Vector2f(x, y)
end

function read_vec3!(c::Ptr{JsonCursor}, x0::Float64, y0::Float64, z0::Float64)::SceneVec3
    x::Float64 = x0
    y::Float64 = y0
    z::Float64 = z0
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return SceneVec3(x, y, z)
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        if key_is(step.key, k"x") == Int32(1)
            x = read_number!(c)
        elseif key_is(step.key, k"y") == Int32(1)
            y = read_number!(c)
        elseif key_is(step.key, k"z") == Int32(1)
            z = read_number!(c)
        else
            skip_value!(c)
        end
    end
    return SceneVec3(x, y, z)
end

function read_vec4!(c::Ptr{JsonCursor})::SceneVec4
    x::Float64 = 0.0
    y::Float64 = 0.0
    z::Float64 = 0.0
    t::Float64 = 0.0
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return SceneVec4(x, y, z, t)
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        if key_is(step.key, k"x") == Int32(1)
            x = read_number!(c)
        elseif key_is(step.key, k"y") == Int32(1)
            y = read_number!(c)
        elseif key_is(step.key, k"z") == Int32(1)
            z = read_number!(c)
        elseif key_is(step.key, k"t") == Int32(1)
            t = read_number!(c)
        else
            skip_value!(c)
        end
    end
    return SceneVec4(x, y, z, t)
end

function read_color!(c::Ptr{JsonCursor})::SceneColor
    r::Int32 = Int32(255)
    g::Int32 = Int32(255)
    b::Int32 = Int32(255)
    a::Int32 = Int32(255)
    if begin_container!(c, UInt8('{')) != Int32(0)
        skip_value!(c)
        return SceneColor(r, g, b, a)
    end
    while true
        step::KeyStep = next_key!(c)
        if step.status != Int32(1)
            break
        end
        if key_is(step.key, k"x") == Int32(1) || key_is(step.key, k"r") == Int32(1)
            r = f64_to_i32(read_number!(c))
        elseif key_is(step.key, k"y") == Int32(1) || key_is(step.key, k"g") == Int32(1)
            g = f64_to_i32(read_number!(c))
        elseif key_is(step.key, k"z") == Int32(1) || key_is(step.key, k"b") == Int32(1)
            b = f64_to_i32(read_number!(c))
        elseif key_is(step.key, k"t") == Int32(1) || key_is(step.key, k"a") == Int32(1)
            a = f64_to_i32(read_number!(c))
        else
            skip_value!(c)
        end
    end
    return SceneColor(r, g, b, a)
end
