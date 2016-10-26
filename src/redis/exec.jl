export exec

exec(conn::AbstractRedisConnection, x...) = acquire(conn) do socket
    resp_send(socket, map(bytify, x)...) |> resp_read
end

bytify(x::Integer) = string(x)
bytify(x::AbstractFloat) = string(x)
bytify(x::AbstractString) = String(x)
bytify(x::Bytes) = x
bytify(x::Byte) = x
