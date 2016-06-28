export RedisBitVector, SubRedisBitVector

immutable RedisBitVector # <: AbstractVector{Bool}
    conn::AbstractRedisConnection
    key::ByteString
end

function getindex(rbv::RedisBitVector, index::Int64)
    exec(rbv.conn, "getbit", rbv.key, index) |> Bool
end

function setindex!(rbv::RedisBitVector, value::Bool, key::Int64)
    exec(rbv.conn, "setbit", key, value?"1":"0")
end

function isnull(rbv::RedisBitVector)
    exec(rbv.conn, "exists", rbv.key) |> Bool
end

function length(rbv::RedisBitVector)
    8 * exec(rbv.conn, "strlen", rbv.key)
end

function sum(rbv::RedisBitVector)
    exec(rbv.conn, "bitcount", rbv.key)
    wait(rbv.conn)::Int64
end

"this methods should always be used in the form of `rbv1 |= rbv2`"
function (|)(rbv1::RedisBitVector, rbv2::RedisBitVector)
    rbv1.conn == rbv2.conn || throw(ArgumentError("tow RedisBitVectors must have the same RedisConnection"))
    exec(rbv1.conn, "bitop", "or", rbv1.key, rbv2.key)
    rbv1
end

"this methods should always be used in the form of `rbv1 &= rbv2`"
function (&)(rbv1::RedisBitVector, rbv2::RedisBitVector)
    rbv1.conn == rbv2.conn || throw(ArgumentError("tow RedisBitVectors must have the same RedisConnection"))
    exec(rbv1.conn, "bitop", "and", rbv1.key, rbv2.key)
    rbv1
end

"this methods should always be used in the form of `rbv1 \$= rbv2`"
function ($)(rbv1::RedisBitVector, rbv2::RedisBitVector)
    rbv1.conn == rbv2.conn || throw(ArgumentError("tow RedisBitVectors must have the same RedisConnection"))
    exec(rbv1.conn, "bitop", "xor", rbv1.key, rbv2.key)
    rbv1
end

"this methods should always be used in the form of `rbv = ~rbv`"
function (~)(rbv::RedisBitVector)
    exec(rbv.conn, "bitop", "not", rbv.key)
    rbv1
end

"Caution: Redis consider the right of the string as padded with zeros, so it may act unexpectly when finding `false`"
function findfirst(rbv::RedisBitVector, v::Bool)
    exec(rbv.conn, "bitpos", rbv.key, v?"1":"0")
    1 + wait(rbv.conn)::Int64
end

findfirst(rbv::RedisBitVector) = findfirst(rbv, true)
