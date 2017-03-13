export exec

exec(conn::AbstractRedisConnection, x...) = acquire(conn) do socket
    resp_send(socket, map(bytify, x)...) |> resp_read
end

exec(c::AbstractRedisCollection, x...) = exec(c.conn, car(x), c.key, cdr(x)...)

bytify(x::Integer) = string(x)
bytify(x::AbstractFloat) = string(x)
bytify(x::AbstractString) = String(x)
bytify(x::Bytes) = x
bytify(x::Byte) = x
