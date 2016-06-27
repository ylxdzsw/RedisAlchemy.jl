export RedisVector

abstract AbstractRedisVector{T} <: AbstractVector{T}

immutable RedisVector{T} <: AbstractRedisVector{T}
    conn::RedisConnection
    key::ASCIIString
    serialize::Function
    deserialize::Function

    RedisVector(conn, key) = if T <: ByteString
        new(conn, key, identity, identity) # maybe use string to ensure type stability?
    elseif T <: Union{Integer, AbstractFloat}
        new(conn, key, string, x -> parse(T, x))
    else
        throw(ArgumentError("RedisVector currently not support arbitrary element type"))
    end
end

immutable SafeRedisVector{T} <: AbstractRedisVector{T}
    conn::RedisConnection
    key::ASCIIString
    serialize::Function
    deserialize::Function

    SafeRedisVector(conn, key) = if T <: ByteString
        new(conn, key, identity, identity) # maybe use string to ensure type stability?
    elseif T <: Union{Integer, AbstractFloat}
        new(conn, key, string, x -> parse(T, x))
    else
        throw(ArgumentError("SafeRedisVector currently not support arbitrary element type"))
    end
end

function getindex{T}(rv::RedisVector{T}, index::Int64)
    res = exec(rv.conn, "lindex", rv.key, zero_index(index))
    res == nothing && throw(BoundsError(rv.conn, index))
    rv.deserialize(res)
end

function getindex{T}(rv::RedisVector{T}, ::Colon)
    res = exec(rv.conn, "lrange", rv.key, 0, -1)
    T[rv.deserialize(i) for i in res]
end

function getindex{T}(rv::RedisVector{T}, x::Integer, y::Integer)
    res = exec(rv.conn, "lrange", rv.key, zero_index(x), zero_index(y))
    res == nothing && throw(BoundsError(rv.conn, index))
    T[rv.deserialize(i) for i in res]
end

function getindex{T}(rv::RedisVector{T}, x::UnitRange)
    rv[x.start, x.stop]
end

function setindex!{T}(rv::RedisVector{T}, value, index::Int64)
    exec(rv.conn, "lset", rv.key, zero_index(index), rv.serialize(T(value)))
end

function setindex!{T}(rv::RedisVector{T}, value::AbstractVector, ::Colon)
    error("not implemented yet")
end

function unshift!{T}(rv::RedisVector{T}, value)
    exec(rv.conn, "lpush", rv.key, rv.serialize(T(value)))
    rv
end

"unshift!(1,2,3) will get [1,2,3], which like julia's unshift! but contrary to Redis's lpush"
function unshift!{T}(rv::RedisVector{T}, values...)
    values = map(rv.serialize∘T, values) |> reverse
    exec(rv.conn, "lpush", rv.key, values...)
    rv
end

function shift!{T}(rv::RedisVector{T})
    res = exec(rv.conn, "lpop", rv.key)
    res == nothing && throw(ArgumentError("Array must be non-empty"))
    rv.deserialize(res)
end

function push!{T}(rv::RedisVector{T}, value)
    exec(rv.conn, "rpush", rv.key, rv.serialize(T(value)))
    rv
end

function push!{T}(rv::RedisVector{T}, values...)
    values = map(rv.serialize∘T, values)
    exec(rv.conn, "rpush", rv.key, values...)
    rv
end

function pop!{T}(rv::RedisVector{T})
    res = exec(rv.conn, "rpop", rv.key)
    res == nothing && throw(ArgumentError("Array must be non-empty"))
    rv.deserialize(res)
end

function length(rv::RedisVector)
    exec(rv.conn, "llen", rv.key)::Int64
end

function size(rv::RedisVector)
    (length(rv),)
end

function isempty(rv::RedisVector)
    length(rv) == 0
end

function sort{T<:Number}(rv::RedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, order)
    T[rv.deserialize(i) for i in res]
end

function sort{T<:ByteString}(rv::RedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, "alpha", order)
    T[rv.deserialize(i) for i in res]
end

function sort!{T<:Number}(rv::RedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, order, "store", rv.key) # returns the length
end

function sort!{T<:ByteString}(rv::RedisVector{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, "alpha", order, "store", rv.key)
end

function show{T}(io::IO, rv::RedisVector{T})
    print(io, "RedisVector{$T}($(rv.conn), \"$(rv.key)\")")
end

function writemime(io::IO, ::MIME"text/plain", v::RedisVector)
    show(io, v)
end
