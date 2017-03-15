export RedisPipe, SafeRedisPipe, RedisBlockedQueue, SafeRedisBlockedQueue,
       enqueue!, dequeue!

abstract AbstractRedisPipe{T} <: AbstractRedisCollection

immutable RedisPipe{T} <: AbstractRedisPipe{T}
    conn::AbstractRedisConnection
    key::String

    RedisPipe(conn, key) = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("RedisPipe currently not supports arbitrary element type"))
    end

    RedisPipe(key) = RedisPipe{T}(default_connection, key)
end

immutable SafeRedisPipe{T} <: AbstractRedisPipe{T}
    conn::AbstractRedisConnection
    key::String

    SafeRedisPipe(conn, key) = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("SafeRedisPipe currently not supports arbitrary element type"))
    end

    SafeRedisPipe(key) = SafeRedisPipe{T}(default_connection, key)
end

reply{T}(rp::AbstractRedisPipe{T}, x::Any) = throw(ProtocolException("unexpected return value $x"))
reply{T}(rp::AbstractRedisPipe{T}, x::Vector) = reply(rp, x[2])
reply{T}(rp::AbstractRedisPipe{T}, x::Bytes) = reply(rp, String(x))

reply{T}(rp::RedisPipe{T}, ::Void) = throw(TimeoutException("timeout"))
reply{T}(rp::RedisPipe{T}, x::String) = deserialize(T, x)

reply{T}(rp::SafeRedisPipe{T}, ::Void) = Nullable{T}()
reply{T}(rp::SafeRedisPipe{T}, x::String) = Nullable(deserialize(T, x))

function read{T}(rp::AbstractRedisPipe{T}, timeout::Integer=0)
    timeout < 0 && throw(ArgumentError("timeout must be non-negative"))
    res = exec(rp.conn, "blpop", rp.key, timeout)
    reply(rp, res)
end

function peek{T}(rp::AbstractRedisPipe{T})
    res = exec(rp.conn, "lindex", rp.key, 0)
    reply(rp, res)
end

function write{T}(rp::AbstractRedisPipe{T}, value)
    exec(rp.conn, "rpush", rp.key, serialize(T(value)))
    rp
end

function length(rp::AbstractRedisPipe)
    exec(rp.conn, "llen", rp.key)::Int64
end

function isempty(rp::AbstractRedisPipe)
    length(rp) == 0
end

function show{T}(io::IO, rp::AbstractRedisPipe{T})
    print(io, "RedisList{$T}($(rp.conn), \"$(rp.key)\")")
end

typealias AbstractRedisBlockedQueue AbstractRedisPipe
typealias RedisBlockedQueue RedisPipe
typealias SafeRedisBlockedQueue SafeRedisPipe

dequeue!{T}(rbq::AbstractRedisBlockedQueue{T}, timeout::Integer=0) = read(rbq, timeout)
enqueue!{T}(rbq::AbstractRedisBlockedQueue{T}, value) = write(rbq, value)
