export RedisCounter

struct RedisCounter{T} <: AbstractRedisCollection
    conn::AbstractRedisConnection
    key::String
end

RedisCounter(key) = RedisCounter{Int}(default_connection, key)

function getindex{T}(rc::RedisCounter{T})
    exec(rc.conn, "incr", rc.key) |> T
end
