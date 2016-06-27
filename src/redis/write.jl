"protocol: http://redis.io/topics/protocol#sending-commands-to-a-redis-server"
function send(conn::RedisConnection, commands::ByteString...)
    conn.socket << '*' << sizeof(commands) << CRLF
    for command in commands
        conn.socket << '$' << sizeof(command) << CRLF << command << CRLF
    end
    conn
end

macro gen_entry(n)
    var(n) = [Symbol("x", x) for x in 1:n]
    str(n) = [:(string($x)) for x in var(n)]
    f = [:(exec(conn, $(var(x)...)) = send(conn, $(str(x)...));) for x in 1:n]
    :( $(f...) )
end

@gen_entry 6

exec(conn, x...) = send(conn, map(string, x)...)
