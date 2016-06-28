export RedisVector, SafeRedisVector

abstract AbstractRedisVector{T} # <: AbstractVector{T}

immutable RedisVector{T} <: AbstractRedisVector{T}
    conn::RedisConnection
    key::ByteString

    RedisVector(conn, key) = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("RedisVector currently not supports arbitrary element type"))
    end
end

immutable SafeRedisVector{T} <: AbstractRedisVector{T}
    conn::RedisConnection
    key::ByteString

    SafeRedisVector(conn, key) = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("SafeRedisVector currently not supports arbitrary element type"))
    end
end

function getindex{T}(rv::RedisVector{T}, index::Int64)
    res = exec(rv.conn, "lindex", rv.key, zero_index(index))
    res == nothing && throw(BoundsError(rv.conn, index))
    deserialize(T, res)
end

function getindex{T}(rv::SafeRedisVector{T}, index::Int64)
    res = exec(rv.conn, "lindex", rv.key, zero_index(index))
    res == nothing && return Nullable{T}()
    Nullable(deserialize(T, res))
end

function getindex{T}(rv::AbstractRedisVector{T}, ::Colon)
    res = exec(rv.conn, "lrange", rv.key, 0, -1)
    T[deserialize(T, i) for i in res]
end

function getindex{T}(rv::AbstractRedisVector{T}, x::Integer, y::Integer)
    res = exec(rv.conn, "lrange", rv.key, zero_index(x), zero_index(y))
    res == nothing && throw(BoundsError(rv.conn, index))
    T[deserialize(T, i) for i in res]
end

function getindex{T}(rv::AbstractRedisVector{T}, x::UnitRange)
    rv[Int(x.start), Int(x.stop)]
end

function setindex!{T}(rv::AbstractRedisVector{T}, value, index::Int64)
    exec(rv.conn, "lset", rv.key, zero_index(index), serialize(T(value)))
end

function setindex!{T}(rv::AbstractRedisVector{T}, value::AbstractVector, ::Colon)
    error("not implemented yet")
end

function unshift!{T}(rv::AbstractRedisVector{T}, value)
    exec(rv.conn, "lpush", rv.key, serialize(T(value)))
    rv
end

"unshift!(1,2,3) will get [1,2,3], which like julia's unshift! but contrary to Redis's lpush"
function unshift!{T}(rv::AbstractRedisVector{T}, values...)
    values = map(serialize∘T, values) |> reverse
    exec(rv.conn, "lpush", rv.key, values...)
    rv
end

function shift!{T}(rv::RedisVector{T})
    res = exec(rv.conn, "lpop", rv.key)
    res == nothing && throw(ArgumentError("Array must be non-empty"))
    deserialize(T, res)
end

function shift!{T}(rv::SafeRedisVector{T})
    res = exec(rv.conn, "lpop", rv.key)
    res == nothing && Nullable{T}()
    Nullable(deserialize(T, res))
end

function push!{T}(rv::AbstractRedisVector{T}, value)
    exec(rv.conn, "rpush", rv.key, serialize(T(value)))
    rv
end

function push!{T}(rv::AbstractRedisVector{T}, values...)
    values = map(serialize∘T, values)
    exec(rv.conn, "rpush", rv.key, values...)
    rv
end

function pop!{T}(rv::RedisVector{T})
    res = exec(rv.conn, "rpop", rv.key)
    res == nothing && throw(ArgumentError("Array must be non-empty"))
    deserialize(T, res)
end

function pop!{T}(rv::SafeRedisVector{T})
    res = exec(rv.conn, "rpop", rv.key)
    res == nothing && Nullable{T}()
    Nullable(deserialize(T, res))
end

function length(rv::AbstractRedisVector)
    exec(rv.conn, "llen", rv.key)::Int64
end

function size(rv::AbstractRedisVector)
    (length(rv),)
end

function isempty(rv::AbstractRedisVector)
    length(rv) == 0
end

function sort{T<:Number}(rv::AbstractRedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, order)
    T[deserialize(T, i) for i in res]
end

function sort{T<:ByteString}(rv::AbstractRedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, "alpha", order)
    T[deserialize(T, i) for i in res]
end

function sort!{T<:Number}(rv::AbstractRedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, order, "store", rv.key) # returns the length
end

function sort!{T<:ByteString}(rv::AbstractRedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, "alpha", order, "store", rv.key)
end

function show{T}(io::IO, rv::AbstractRedisVector{T})
    print(io, "RedisList{$T}($(rv.conn), \"$(rv.key)\")")
end
