export RedisList, SafeRedisList

abstract AbstractRedisList{T} # <: AbstractVector{T}

immutable RedisList{T} <: AbstractRedisList{T}
    conn::AbstractRedisConnection
    key::String

    RedisList(conn, key) = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("RedisList currently not supports arbitrary element type"))
    end

    RedisList(key) = RedisList{T}(default_connection, key)
end

immutable SafeRedisList{T} <: AbstractRedisList{T}
    conn::AbstractRedisConnection
    key::String

    SafeRedisList(conn, key) = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("SafeRedisList currently not supports arbitrary element type"))
    end

    SafeRedisList(key) = SafeRedisList{T}(default_connection, key)
end

function getindex{T}(rv::RedisList{T}, index::Int64)
    res = exec(rv.conn, "lindex", rv.key, zero_index(index))
    res == nothing && throw(BoundsError(rv, index))
    deserialize(T, res)
end

function getindex{T}(rv::SafeRedisList{T}, index::Int64)
    res = exec(rv.conn, "lindex", rv.key, zero_index(index))
    res == nothing && return Nullable{T}()
    Nullable(deserialize(T, res))
end

function getindex{T}(rv::AbstractRedisList{T}, ::Colon)
    res = exec(rv.conn, "lrange", rv.key, 0, -1)
    T[deserialize(T, i) for i in res]
end

function getindex{T}(rv::AbstractRedisList{T}, x::Integer, y::Integer)
    res = exec(rv.conn, "lrange", rv.key, zero_index(x), zero_index(y))
    res == nothing && throw(BoundsError(rv, index))
    T[deserialize(T, i) for i in res]
end

function getindex{T, S<:Integer}(rv::AbstractRedisList{T}, x::UnitRange{S})
    rv[Int(x.start), Int(x.stop)]
end

function setindex!{T}(rv::AbstractRedisList{T}, value, index::Int64)
    exec(rv.conn, "lset", rv.key, zero_index(index), serialize(T, value))
end

function collect(rv::AbstractRedisList)
    rv[:]
end

function unshift!{T}(rv::AbstractRedisList{T}, value)
    exec(rv.conn, "lpush", rv.key, serialize(T, value))
    rv
end

"unshift!(1,2,3) will get [1,2,3], which like julia's unshift! but contrary to Redis's lpush"
function unshift!{T}(rv::AbstractRedisList{T}, values...)
    values = map(serialize∘T, values) |> reverse
    exec(rv.conn, "lpush", rv.key, values...)
    rv
end

function shift!{T}(rv::RedisList{T})
    res = exec(rv.conn, "lpop", rv.key)
    res == nothing && throw(ArgumentError("Array must be non-empty"))
    deserialize(T, res)
end

function shift!{T}(rv::SafeRedisList{T})
    res = exec(rv.conn, "lpop", rv.key)
    res == nothing && Nullable{T}()
    Nullable(deserialize(T, res))
end

function push!{T}(rv::AbstractRedisList{T}, value)
    exec(rv.conn, "rpush", rv.key, serialize(T, value))
    rv
end

function push!{T}(rv::AbstractRedisList{T}, values...)
    values = map(serialize∘T, values)
    exec(rv.conn, "rpush", rv.key, values...)
    rv
end

function pop!{T}(rv::RedisList{T})
    res = exec(rv.conn, "rpop", rv.key)
    res == nothing && throw(ArgumentError("Array must be non-empty"))
    deserialize(T, res)
end

function pop!{T}(rv::SafeRedisList{T})
    res = exec(rv.conn, "rpop", rv.key)
    res == nothing && Nullable{T}()
    Nullable(deserialize(T, res))
end

function length(rv::AbstractRedisList)
    exec(rv.conn, "llen", rv.key)::Int64
end

function size(rv::AbstractRedisList)
    (length(rv),)
end

function isempty(rv::AbstractRedisList)
    length(rv) == 0
end

function sort{T<:Number}(rv::AbstractRedisList{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, order)
    T[deserialize(T, i) for i in res]
end

function sort{T<:AbstractString}(rv::AbstractRedisList{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, "alpha", order)
    T[deserialize(T, i) for i in res]
end

function sort!{T<:Number}(rv::AbstractRedisList{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, order, "store", rv.key)::Int64 # returns the length
end

function sort!{T<:AbstractString}(rv::AbstractRedisList{T}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, "alpha", order, "store", rv.key)::Int64
end

function show{T}(io::IO, rv::AbstractRedisList{T})
    print(io, "RedisList{$T}($(rv.conn), \"$(rv.key)\")")
end

"""
iterator batch 12 elements a round.
"""
const BATCHSIZE = 12

function fetch_batch(rv::AbstractRedisList, index)
    rv[index:index+BATCHSIZE-1]
end

function start(rv::AbstractRedisList)
    cache = fetch_batch(rv, 1)
    cache, start(cache), 1+BATCHSIZE
end

function next(rv::AbstractRedisList, iter)
    cache, ci, index = iter
    res, ci = next(cache, ci)

    iter = if done(cache, ci)
        cache = fetch_batch(rv, index)
        cache, start(cache), index + BATCHSIZE
    else
        cache, ci, index
    end

    res, iter
end

function done(rv::AbstractRedisList, iter)
    cache, ci, index = iter
    done(cache, ci)
end
