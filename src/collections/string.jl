export RedisString, SafeRedisString

abstract AbstractRedisString # <: AbstractString

immutable RedisString <: AbstractRedisString
    conn::AbstractRedisConnection
    key::ByteString
end

immutable SafeRedisString <: AbstractRedisString
    conn::AbstractRedisConnection
    key::ByteString
end

"NOTE: Redis count index by byte, while julia count by char"
function getindex(rs::AbstractRedisString, x::Integer, y::Integer)
    # it is always not null: non-exist keys are treated as empty string by redis
    exec(rs.conn, "getrange", rs.key, zero_index(x), zero_index(y))::ByteString
end

function getindex{T<:Integer}(rs::AbstractRedisString, x::UnitRange{T})
    rs[x.start, x.stop]
end

function getindex(rs::AbstractRedisString, x::Integer) # do we really need this?
    rs[x, x][1]
end

function getindex(rs::RedisString, ::Colon=Colon())
    res = exec(rs.conn, "get", rs.key)
    res == nothing && throw(NullException())
    res::ByteString
end

function getindex(rs::SafeRedisString, ::Colon=Colon())
    exec(rs.conn, "get", rs.key) |> Nullable{ByteString}
end

function setindex!(rs::AbstractRedisString, value, offset::Integer)
    exec(rs.conn, "setrange", rs.key, offset, value)
    rs
end

function setindex!{T<:Integer}(rs::AbstractRedisString, value, x::UnitRange{T})
    value = value |> string |> bytestring
    x.stop - x.start + 1 == sizeof(value) || throw(DimensionMismatch())
    rs[x.start] = value
    rs
end

function setindex!(rs::AbstractRedisString, value, ::Colon=Colon())
    exec(rs.conn, "set", rs.key, value)
    rs
end

"this methods should always be used in the form of `rs += xx`"
function (+)(rs::SafeRedisString, value)
    exec(rs.conn, "append", rs.key, value)
    rs
end

"NOTE: Redis count length by byte, while julia count by char"
function length(rs::AbstractRedisString)
    exec(rs.conn, "strlen", rs.key)::Int64
end

function string(rs::AbstractRedisString)
    rs[:]
end

function show(io::IO, rs::AbstractRedisString)
    print(io, "RedisString($(rs.conn), \"$(rs.key)\")")
end
