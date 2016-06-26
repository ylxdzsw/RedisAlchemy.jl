"""
protocol: http://redis.io/topics/protocol#sending-commands-to-a-redis-server
converts any thing to string before send to redis
"""
function send(conn::RedisConnection, commands...)
    conn << '*' << length(commands) << CRLF
    for command in commands
        command = command |> string
        conn << '$' << length(command) << CRLF << command << CRLF
    end
    conn
end
