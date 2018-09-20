export RedisDict

struct RedisDict{K,V} <: AbstractRedisCollection
    conn::AbstractRedisConnection
    key::String

    RedisDict{K,V}(conn, key) where {K,V} = if serializeable(K) && serializeable(V)
        new(conn, key)
    elseif V == Nothing
        throw(ArgumentError("Sorry RedisDict don't support Nothing as value"))
    else
        throw(ArgumentError("RedisDict currently not supports arbitrary element type"))
    end

    RedisDict{K,V}(key) where {K,V} = RedisDict{K,V}(default_connection, key)
end

struct RedisDictKeyIterator{K,V}
    rd::RedisDict{K,V}
end

struct RedisDictValueIterator{K,V}
    rd::RedisDict{K,V}
end

function getindex(rd::RedisDict{K,V}, key) where {K,V}
    res = exec(rd.conn, "hget", rd.key, serialize(K, key))
    deserialize(V, @some(res))
end

function get(rd::RedisDict{K,V}, key, default) where {K,V}
    res = exec(rd.conn, "hget", rd.key, serialize(K, key))
    res == nothing ? default : deserialize(V, res)
end

function setindex!(rd::RedisDict{K,V}, value, key) where {K,V}
    exec(rd.conn, "hset", rd.key, serialize(K, key), serialize(V, value))
end

function keys(rd::RedisDict)
    RedisDictKeyIterator(rd)
end

function values(rd::RedisDict)
    RedisDictValueIterator(rd)
end

function keytype(::RedisDict{K,V}) where {K,V}
    K
end

function valtype(::RedisDict{K,V}) where {K,V}
    V
end

function eltype(::RedisDict{K,V}) where {K,V}
    Pair{K,V}
end

function eltype(::RedisDictKeyIterator{K,V}) where {K,V}
    K
end

function eltype(::RedisDictValueIterator{K,V}) where {K,V}
    V
end

function length(rd::RedisDict)
    exec(rd.conn, "hlen", rd.key)::Int64
end

function length(ki::RedisDictKeyIterator)
    length(ki.rd)
end

function length(vi::RedisDictValueIterator)
    length(vi.rd)
end

function iterate(rd::RedisDict)
    handle, cache = exec(rd.conn, "hscan", rd.key, 0)
    iterate(rd, (cache, 1, parse(Int, String(handle))))
end

function iterate(rd::RedisDict{K,V}, (cache, ci, handle)) where {K,V}
    ci > length(cache) && return nothing

    cache[ci], cache[ci+1], if ci+2 > length(cache) && handle != 0
        handle, cache = exec(rd.conn, "hscan", rd.key, handle)
        cache, 1, parse(Int, String(handle))
    else
        cache, ci+2, handle
    end

    Pair(deserialize(K, key), deserialize(V, val)), iter
end

"simply delegate to the Dict, will do extra deserializations for value"
function iterate(ki::RedisDictKeyIterator)
    res, state = @some iterate(ki.rd)
    car(res), state
end

function iterate(ki::RedisDictKeyIterator, state)
    res, state = @some iterate(ki.rd, state)
    car(res), state
end

"simply delegate to the Dict, will do extra deserializations for key"
function iterate(vi::RedisDictValueIterator)
    res, state = @some iterate(vi.rd)
    cadr(res), state
end

function iterate(vi::RedisDictValueIterator, iter)
    res, state = @some iterate(vi.rd, state)
    cadr(res), state
end

function collect(rd::RedisDict{K,V}) where {K,V}
    raw = exec(rd.conn, "hgetall", rd.key)
    res = Vector{Pair{K,V}}(length(raw)÷2)

    for i in 1:length(raw)÷2
        res[i] = Pair(deserialize(K, raw[2i-1]), deserialize(V, raw[2i]))
    end

    res
end

function collect(ki::RedisDictKeyIterator{K,V}) where {K,V}
    map(deserialize(K), exec(ki.rd.conn, "hkeys", ki.rd.key))
end

function in(x::Pair, rd::RedisDict)
    cadr(x) != nothing && rd[car(x)] == cadr(x)
end

function in(x, rd::RedisDict)
    throw(ArgumentError("Dicts only contain Pairs"))
end

function in(x, ki::RedisDictKeyIterator{K,V}) where {K,V}
    exec(ki.rd.conn, "hexists", ki.rd.key, serialize(K, x)) |> Bool
end
