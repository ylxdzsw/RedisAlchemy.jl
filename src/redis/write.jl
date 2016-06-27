"protocol: http://redis.io/topics/protocol#sending-commands-to-a-redis-server"
function send(conn::RedisConnection, commands::ByteString...)
    conn.socket << '*' << length(commands) << CRLF
    for command in commands
        conn.socket << '$' << sizeof(command) << CRLF << command << CRLF
    end
    conn
end
