export RedisConnection, exec

immutable RedisConnection <: IO
    socket::TCPSocket
end

function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    connection = connect(host, port) |> RedisConnection
    # TODO send password and select db
end

close(x::RedisConnection) = close(x.socket)

macro gen_entry(n)
    var(n) = [symbol("x", x) for x in 1:n]
    str(n) = [:(string($x)) for x in var(n)]
    f = [:(exec(conn::RedisConnection, $(var(x)...)) = send(conn, $(str(x)...)) |> wait;) for x in 1:n]
    :( $(f...) )
end

@gen_entry 6

exec(conn::RedisConnection, x...) = send(conn, map(string, x)...) |> wait
