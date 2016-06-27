export RedisBitVector, SubRedisBitVector

immutable RedisBitVector <: AbstractVector{Bool}
    conn::RedisConnection
    key::ASCIIString
end

function getindex(rbv::RedisBitVector, index::Int64)
    send(rbv.conn, "getbit", rbv.key, index) |> wait |> Bool
end

function setindex!(rbv::RedisBitVector, value::Bool, key::Int64)
    send(rbv.conn, "setbit", key, value?"1":"0")
    wait(rbv.conn) == "ok" || throw(ProtocolException("expect \"ok\""))
end

function isnull(rbv::RedisBitVector)
    send(rbv.conn, "exists", rbv.key) |> wait |> Bool
end

function length(rbv::RedisBitVector)
    send(rbv.conn, "strlen", rbv.key)
    8 * wait(rbv.conn)::Int64
end

function sum(rbv::RedisBitVector)
    send(rbv.conn, "bitcount", rbv.key)
    wait(rbv.conn)::Int64
end

"this methods should always be used in the form of `rbv1 |= rbv2`"
function |(rbv1::RedisBitVector, rbv2::RedisBitVector)
    rbv1.conn == rbv2.conn || throw(ArgumentError("tow RedisBitVectors must have the same RedisConnection"))
    send(rbv1.conn, "bitop", "or", rbv1.key, rbv2.key) |> wait
    rbv1
end

"this methods should always be used in the form of `rbv1 &= rbv2`"
function &(rbv1::RedisBitVector, rbv2::RedisBitVector)
    rbv1.conn == rbv2.conn || throw(ArgumentError("tow RedisBitVectors must have the same RedisConnection"))
    send(rbv1.conn, "bitop", "and", rbv1.key, rbv2.key) |> wait
    rbv1
end

"this methods should always be used in the form of `rbv1 $= rbv2`"
function $(rbv1::RedisBitVector, rbv2::RedisBitVector)
    rbv1.conn == rbv2.conn || throw(ArgumentError("tow RedisBitVectors must have the same RedisConnection"))
    send(rbv1.conn, "bitop", "xor", rbv1.key, rbv2.key) |> wait
    rbv1
end

"this methods should always be used in the form of `rbv = ~rbv`"
function ~(rbv::RedisBitVector)
    send(rbv.conn, "bitop", "not", rbv.key) |> wait
    rbv1
end

"Caution: Redis consider the right of the string as padded with zeros, so it may act unexpectly when finding `false`"
function findfirst(rbv::RedisBitVector, v::Bool)
    send(rbv.conn, "bitpos", rbv.key, v?"1":"0")
    1 + wait(rbv.conn)::Int64
end

findfirst(rbv::RedisBitVector) = findfirst(rbv, true)

immutable SubRedisBitVector <: AbstractVector{Bool}
    rbv::RedisBitVector
    range::UnitRange{Int64} # range in bytes
end

function length(srbv::SubRedisBitVector)
    length(srbv.range) * 8
end
