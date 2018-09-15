export RedisString, SafeRedisString

abstract type AbstractRedisString <: AbstractRedisCollection end

struct RedisString <: AbstractRedisString
    conn::AbstractRedisConnection
    key::String
end

RedisString(key) = RedisString(default_connection, key)

struct SafeRedisString <: AbstractRedisString
    conn::AbstractRedisConnection
    key::String
end

SafeRedisString(key) = SafeRedisString(default_connection, key)

function getindex(rs::AbstractRedisString, x::Integer, y::Integer)
    # it is always not null: non-exist keys are treated as empty string by redis
    exec(rs.conn, "getrange", rs.key, zero_index(x), zero_index(y)) |> String
end

function getindex(rs::AbstractRedisString, x::UnitRange{T}) where T<:Integer
    rs[x.start, x.stop]
end

function getindex(rs::AbstractRedisString, x::Integer) # do we really need this?
    rs[x, x][1]
end

function getindex(rs::RedisString, ::Colon=Colon())
    res = exec(rs.conn, "get", rs.key)
    res == nothing && throw(KeyError(rs.key))
    res |> String
end

function getindex(rs::SafeRedisString, ::Colon=Colon())
    res = exec(rs.conn, "get", rs.key)
    res |> Nullable{String}
end

function setindex!(rs::AbstractRedisString, value, offset::Integer)
    exec(rs.conn, "setrange", rs.key, zero_index(offset), value)
    rs
end

function setindex!(rs::AbstractRedisString, value, x::UnitRange{T}) where T<:Integer
    value = value |> string |> String
    x.stop - x.start + 1 == sizeof(value) || throw(DimensionMismatch())
    rs[x.start] = value
    rs
end

function setindex!(rs::AbstractRedisString, value, ::Colon=Colon())
    exec(rs.conn, "set", rs.key, value)
    rs
end

"this methods should always be used in the form of `rs += xx`"
function (+)(rs::AbstractRedisString, value)
    exec(rs.conn, "append", rs.key, value)
    rs
end

"NOTE: Redis count length by byte, while julia count by char"
function length(rs::AbstractRedisString)
    exec(rs.conn, "strlen", rs.key)::Int64
end

function endof(rs::AbstractRedisString)
    length(rs)
end

function string(rs::AbstractRedisString)
    rs[:]
end

function show(io::IO, rs::AbstractRedisString)
    print(io, "RedisString($(rs.conn), \"$(rs.key)\")")
end
