export RedisString, SafeRedisString

abstract AbstractRedisString <: AbstractString

immutable RedisString <: AbstractRedisString
    conn::RedisConnection
end

immutable SafeRedisString <: AbstractRedisString
    conn::RedisConnection
end

function getindex(rs::RedisString, key::ASCIIString)
    send(rs.conn, "get", key)
    wait(rs.conn)::ByteString
end

function getindex(rs::RedisString, key::ASCIIString)
    send(rs.conn, "get", key) |> wait |> Nullable{ByteString}
end

function setindex!(rs::AbstractRedisString, value, key::ASCIIString)
    send(rs.conn, "set", key, value)
    wait(rs.conn) |> Bool
end
