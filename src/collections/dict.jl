export RedisDict, SafeRedisDict

abstract AbstractRedisDict{K,V} # <: Associative{K,V}

immutable RedisDict{K,V} <: AbstractRedisDict{K,V}
    conn::AbstractRedisConnection
    key::String

    RedisDict(conn, key) = if serializeable(K) && serializeable(V)
        new(conn, key)
    else
        throw(ArgumentError("RedisDict currently not supports arbitrary element type"))
    end

    RedisDict(key) = RedisDict{K,V}(default_connection, key)
end

immutable SafeRedisDict{K,V} <: AbstractRedisDict{K,V}
    conn::AbstractRedisConnection
    key::String

    SafeRedisDict(conn, key) = if serializeable(K) && serializeable(V)
        new(conn, key)
    else
        throw(ArgumentError("SafeRedisDict currently not supports arbitrary element type"))
    end

    SafeRedisDict(key) = SafeRedisDict{K,V}(default_connection, key)
end

immutable RedisDictKeyIterator{K,V}
    rd::AbstractRedisDict{K,V}
end

immutable RedisDictValueIterator{K,V}
    rd::AbstractRedisDict{K,V}
end

function getindex{K,V}(rd::RedisDict{K,V}, key)
    res = exec(rd.conn, "hget", rd.key, serialize(K, key))
    res == nothing && throw(KeyError(key))
    deserialize(V, res)
end

function getindex{K,V}(rd::SafeRedisDict{K,V}, key)
    res = exec(rd.conn, "hget", rd.key, serialize(K, key))
    res == nothing && return Nullable{V}()
    Nullable(deserialize(V, res))
end

function setindex!{K,V}(rd::AbstractRedisDict{K,V}, value, key)
    exec(rd.conn, "hset", rd.key, serialize(K, key), serialize(V, value))
end

function keys(rd::AbstractRedisDict)
    RedisDictKeyIterator(rd)
end

function values(rd::AbstractRedisDict)
    RedisDictValueIterator(rd)
end

function keytype{K,V}(::AbstractRedisDict{K,V})
    K
end

function valtype{K,V}(::AbstractRedisDict{K,V})
    V
end

function eltype{K,V}(::AbstractRedisDict{K,V})
    Pair{K,V}
end

function eltype{K,V}(::RedisDictKeyIterator{K,V})
    K
end

function eltype{K,V}(::RedisDictValueIterator{K,V})
    V
end

function length(rd::AbstractRedisDict)
    exec(rd.conn, "hlen", rd.key)::Int64
end

function length(ki::RedisDictKeyIterator)
    length(ki.rd)
end

function length(vi::RedisDictValueIterator)
    length(vi.rd)
end

function start(rd::AbstractRedisDict)
    handle, cache = exec(rd.conn, "hscan", rd.key, 0)
    handle = parse(Int, String(handle))
    cache, start(cache), handle
end

function next{K,V}(rd::AbstractRedisDict{K,V}, iter)
    cache, ci, handle = iter
    key, ci = next(cache, ci)
    val, ci = next(cache, ci)

    iter = if done(cache, ci) && handle != 0
        handle, cache = exec(rd.conn, "hscan", rd.key, handle)
        handle = parse(Int, String(handle))
        cache, start(cache), handle
    else
        cache, ci, handle
    end

    Pair(deserialize(K, key), deserialize(V, val)), iter
end

function done(rd::AbstractRedisDict, iter)
    cache, ci, handle = iter
    done(cache, ci)
end

"simply delegate to the Dict, will do extra deserializations for value"
function start(ki::RedisDictKeyIterator)
    start(ki.rd)
end

function next(ki::RedisDictKeyIterator, iter)
    res, iter = next(ki.rd, iter)
    car(res), iter
end

function done(ki::RedisDictKeyIterator, iter)
    done(ki.rd, iter)
end

"simply delegate to the Dict, will do extra deserializations for key"
function start(vi::RedisDictValueIterator)
    start(vi.rd)
end

function next(vi::RedisDictValueIterator, iter)
    res, iter = next(vi.rd, iter)
    cadr(res), iter
end

function done(vi::RedisDictValueIterator, iter)
    done(vi.rd, iter)
end

function collect{K,V}(rd::AbstractRedisDict{K,V})
    raw = exec(rd.conn, "hgetall", rd.key)
    res = Vector{Pair{K,V}}(length(raw)÷2)

    for i in 1:length(raw)÷2
        res[i] = Pair(deserialize(K, raw[2i-1]), deserialize(V, raw[2i]))
    end

    res
end

function collect{K,V}(ki::RedisDictKeyIterator{K,V})
    map(deserialize(K), exec(ki.rd.conn, "hkeys", ki.rd.key))
end

function in(x::Pair, rd::RedisDict)
    try
        rd[car(x)] == cadr(x)
    catch
        false
    end
end

function in(x::Pair, rd::SafeRedisDict)
    res = rd[car(x)]
    !isnull(res) && res.value == cadr(x)
end

function in(x, rd::AbstractRedisDict)
    throw(ArgumentError("Dicts only contain Pairs"))
end

function in{K,V}(x, ki::RedisDictKeyIterator{K,V})
    exec(ki.rd.conn, "hexists", ki.rd.key, serialize(K, x)) |> Bool
end
