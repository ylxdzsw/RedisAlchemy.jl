export RedisString

struct RedisString <: AbstractRedisCollection
    conn::AbstractRedisConnection
    key::String
end

RedisString(key) = RedisString(default_connection, key)

function getindex(rs::RedisString, x::Integer, y::Integer)
    # it is always not null: non-exist keys are treated as empty string by redis
    exec(rs.conn, "getrange", rs.key, zero_index(x), zero_index(y)) |> String
end

function getindex(rs::RedisString, x::UnitRange{T}) where T<:Integer
    rs[x.start, x.stop]
end

function getindex(rs::RedisString, x::Integer) # do we really need this?
    rs[x, x][1]
end

function getindex(rs::RedisString, ::Colon=Colon())
    String(@some(exec(rs.conn, "get", rs.key)))
end

function setindex!(rs::RedisString, value, offset::Integer)
    exec(rs.conn, "setrange", rs.key, zero_index(offset), value)
    rs
end

function setindex!(rs::RedisString, value, x::UnitRange{T}) where T<:Integer
    value = value |> string |> String
    x.stop - x.start + 1 == sizeof(value) || throw(DimensionMismatch())
    rs[x.start] = value
    rs
end

function setindex!(rs::RedisString, value, ::Colon=Colon())
    exec(rs.conn, "set", rs.key, value)
    rs
end

"this methods should always be used in the form of `rs += xx`"
function (+)(rs::RedisString, value)
    exec(rs.conn, "append", rs.key, value)
    rs
end

"NOTE: Redis count length by byte, while julia count by char"
function length(rs::RedisString)
    exec(rs.conn, "strlen", rs.key)::Int64
end

function lastindex(rs::RedisString)
    length(rs)
end

function string(rs::RedisString)
    rs[:]
end
