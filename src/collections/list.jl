export RedisList

struct RedisList{T} <: AbstractRedisCollection
    conn::AbstractRedisConnection
    key::String

    RedisList{T}(conn, key) where T = if serializeable(T)
        new(conn, key)
    else
        throw(ArgumentError("RedisList currently does not support arbitrary element type"))
    end

    RedisList{T}(key) where T = RedisList{T}(default_connection, key)
end

function getindex(rv::RedisList{T}, index::Int64) where T
    res = exec(rv.conn, "lindex", rv.key, zero_index(index))
    deserialize(T, @some(res))
end

function getindex(rv::RedisList{T}, ::Colon) where T
    res = exec(rv.conn, "lrange", rv.key, 0, -1)
    map(deserialize(T), res)
end

function getindex(rv::RedisList{T}, x::Integer, y::Integer) where T
    res = exec(rv.conn, "lrange", rv.key, zero_index(x), zero_index(y))
    map(deserialize(T), res)
end

function getindex(rv::RedisList, x::UnitRange{<:Integer})
    rv[Int(x.start), Int(x.stop)]
end

function setindex!(rv::RedisList{T}, value, index::Int64) where T
    exec(rv.conn, "lset", rv.key, zero_index(index), serialize(T, value))
end

function collect(rv::RedisList)
    rv[:]
end

function unshift!(rv::RedisList{T}, value) where T
    exec(rv.conn, "lpush", rv.key, serialize(T, value))
    rv
end

"pushfirst!([],1,2,3) will get [1,2,3], which like julia's pushfirst! but contrary to Redis's lpush"
function pushfirst!(rv::RedisList{T}, values...) where T
    values = map(serialize∘T, values) |> reverse
    exec(rv.conn, "lpush", rv.key, values...)
    rv
end

function popfirst!(rv::RedisList{T}) where T
    res = exec(rv.conn, "lpop", rv.key)
    deserialize(T, @some(res))
end

function push!(rv::RedisList{T}, value) where T
    exec(rv.conn, "rpush", rv.key, serialize(T, value))
    rv
end

function push!(rv::RedisList{T}, values...) where T
    values = map(serialize∘T, values)
    exec(rv.conn, "rpush", rv.key, values...)
    rv
end

function pop!(rv::RedisList{T}) where T
    res = exec(rv.conn, "rpop", rv.key)
    deserialize(T, @some(res))
end

function length(rv::RedisList)
    exec(rv.conn, "llen", rv.key)::Int64
end

function lastindex(rv::RedisList)
    length(rv)
end

function size(rv::RedisList)
    (length(rv),)
end

function isempty(rv::RedisList)
    length(rv) == 0
end

function sort(rv::RedisList{T}; rev::Bool=false) where T <: Number
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, order)
    T[deserialize(T, i) for i in res]
end

function sort(rv::RedisList{T}; rev::Bool=false) where T <: AbstractString
    order = rev ? "desc" : "asc"
    res = exec(rv.conn, "sort", rv.key, "alpha", order)
    T[deserialize(T, i) for i in res]
end

function sort!(rv::RedisList{<:Number}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, order, "store", rv.key)::Int64 # returns the length
end

function sort!(rv::RedisList{<:AbstractString}; rev::Bool=false)
    order = rev ? "desc" : "asc"
    exec(rv.conn, "sort", rv.key, "alpha", order, "store", rv.key)::Int64
end

"""
iterator batch 12 elements a round.
"""
const BATCHSIZE = 12

function fetch_batch(rv::RedisList, index)
    rv[index:index+BATCHSIZE-1]
end

function iterate(rv::RedisList)
    cache = fetch_batch(rv, 1)
    iterate(rv, (cache, 1, 1+BATCHSIZE))
end

function iterate(rv::RedisList, (cache, ci, index))
    ci > length(cache) && return nothing

    cache[ci], if ci+1 > length(cache)
        cache = fetch_batch(rv, index)
        cache, 1, index + BATCHSIZE
    else
        cache, ci+1, index
    end
end

function eltype(::Type{RedisList{T}}) where T
    T
end
