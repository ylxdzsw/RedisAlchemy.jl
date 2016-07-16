export exec

call_redis(socket::TCPSocket, x...) = resp_send(socket, map(bytify, x)...) |> resp_read

exec(conn::RedisConnection, x...) = begin
    acquire(conn)
    try
        call_redis(conn.socket, x...)
    finally
        release(conn)
    end
end

exec(pool::RedisConnectionPool, x...) = begin
    socket = find_avaliable(pool)
    try
        call_redis(socket, x...)
    finally
        add_connection(pool, socket)
        notify(pool.cond, all=false)
    end
end

bytify(x::Integer) = string(x)
bytify(x::AbstractFloat) = string(x)
bytify(x::AbstractString) = bytestring(x)
bytify(x::Bytes) = x
bytify(x::Byte) = x
bytify(x::ByteString) = x
