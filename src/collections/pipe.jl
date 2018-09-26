export RedisPipe

struct RedisPipe{T} <: AbstractRedisCollection
    conn::AbstractRedisConnection
    key::String

    RedisPipe{T}(conn, key) where T = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("RedisPipe currently not supports arbitrary element type"))
    end

    RedisPipe{T}(key) where T = RedisPipe{T}(default_connection, key)
end

reply(rp::RedisPipe, x) = throw(ProtocolException("unexpected return value $x"))
reply(rp::RedisPipe, x::Vector) = reply(rp, x[2])
reply(rp::RedisPipe, x::String) = reply(rp, x.data)
reply(rp::RedisPipe, ::Nothing) = throw(TimeoutException("timeout"))
reply(rp::RedisPipe{T}, x::Bytes) where T = deserialize(T, x)

function read(rp::RedisPipe, timeout::Integer=0)
    timeout < 0 && throw(ArgumentError("timeout must be non-negative"))
    res = exec(rp.conn, "blpop", rp.key, timeout)
    reply(rp, res)
end

take!(rp::RedisPipe, timeout::Integer=0) = read(rp, timeout)

function peek(rp::RedisPipe)
    res = exec(rp.conn, "lindex", rp.key, 0)
    reply(rp, @some(res))
end

function write(rp::RedisPipe{T}, value) where T
    exec(rp.conn, "rpush", rp.key, serialize(T, value))
    rp
end

put!(rp::RedisPipe, value) = write(rp, value)

function length(rp::RedisPipe)
    exec(rp.conn, "llen", rp.key)::Int64
end

function isempty(rp::RedisPipe)
    length(rp) == 0
end
