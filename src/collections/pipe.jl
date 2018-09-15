export RedisPipe, SafeRedisPipe, RedisBlockedQueue, SafeRedisBlockedQueue,
       enqueue!, dequeue!

abstract type AbstractRedisPipe{T} <: AbstractRedisCollection end

struct RedisPipe{T} <: AbstractRedisPipe{T}
    conn::AbstractRedisConnection
    key::String

    RedisPipe{T}(conn, key) where T = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("RedisPipe currently not supports arbitrary element type"))
    end

    RedisPipe{T}(key) where T = RedisPipe{T}(default_connection, key)
end

struct SafeRedisPipe{T} <: AbstractRedisPipe{T}
    conn::AbstractRedisConnection
    key::String

    SafeRedisPipe{T}(conn, key) where T = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("SafeRedisPipe currently not supports arbitrary element type"))
    end

    SafeRedisPipe{T}(key) where T = SafeRedisPipe{T}(default_connection, key)
end

reply(rp::AbstractRedisPipe{T}, x::Any) where {T} = throw(ProtocolException("unexpected return value $x"))
reply(rp::AbstractRedisPipe{T}, x::Vector) where {T} = reply(rp, x[2])
reply(rp::AbstractRedisPipe{T}, x::String) where {T} = reply(rp, x.data)

reply(rp::RedisPipe{T}, ::Void) where {T} = throw(TimeoutException("timeout"))
reply(rp::RedisPipe{T}, x::Bytes) where {T} = deserialize(T, x)

reply(rp::SafeRedisPipe{T}, ::Void) where {T} = Nullable{T}()
reply(rp::SafeRedisPipe{T}, x::Bytes) where {T} = Nullable(deserialize(T, x))

function read(rp::AbstractRedisPipe{T}, timeout::Integer=0) where T
    timeout < 0 && throw(ArgumentError("timeout must be non-negative"))
    res = exec(rp.conn, "blpop", rp.key, timeout)
    reply(rp, res)
end

function peek(rp::AbstractRedisPipe{T}) where T
    res = exec(rp.conn, "lindex", rp.key, 0)
    reply(rp, res)
end

function write(rp::AbstractRedisPipe{T}, value) where T
    exec(rp.conn, "rpush", rp.key, serialize(T(value)))
    rp
end

function length(rp::AbstractRedisPipe)
    exec(rp.conn, "llen", rp.key)::Int64
end

function isempty(rp::AbstractRedisPipe)
    length(rp) == 0
end

function show(io::IO, rp::AbstractRedisPipe{T}) where T
    print(io, "RedisList{$T}($(rp.conn), \"$(rp.key)\")")
end

const AbstractRedisBlockedQueue = AbstractRedisPipe
const RedisBlockedQueue         = RedisPipe
const SafeRedisBlockedQueue     = SafeRedisPipe

dequeue!(rbq::AbstractRedisBlockedQueue{T}, timeout::Integer=0) where {T} = read(rbq, timeout)
enqueue!(rbq::AbstractRedisBlockedQueue{T}, value) where {T} = write(rbq, value)
