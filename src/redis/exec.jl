export exec

macro gen_entry(n)
    var(n) = [symbol("x", x) for x in 1:n]
    str(n) = [:(bytestring(string($x))) for x in var(n)]
    f = [:(call_redis(socket::TCPSocket, $(var(x)...)) = resp_send(socket, $(str(x)...)) |> resp_read;) for x in 1:n]
    :( $(f...) )
end

@gen_entry 6

call_redis(socket::TCPSocket, x...) = resp_send(socket, map(bytestring∘string, x)...) |> resp_read

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
