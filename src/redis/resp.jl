#protocol: http://redis.io/topics/protocol

"`commands` can be any thing that `write` and `sizeof` works properly"
function resp_send(socket::TCPSocket, commands...)
    buf = IOBuffer() # it turns out that buffering can boost the performance by magnititude.
    buf << '*' << length(commands) << CRLF
    for command in commands
        buf << '$' << sizeof(command) << CRLF << command << CRLF
    end
    socket << take!(buf) # since isnull(socket.sendbuf), no need to flush here
end

"possible return types: Int64, String, Bytes, Vector and Void"
function resp_read(socket::TCPSocket)
    magic_byte = socket >> Byte
    line = socket >> readline

    if magic_byte == Byte('+')
        line
    elseif magic_byte == Byte('-')
        RedisException(line) |> throw
    elseif magic_byte == Byte(':')
        parse(Int64, line)
    elseif magic_byte == Byte('$')
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        socket >> (len + 2) |> chomp!
    elseif magic_byte == Byte('*')
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        [resp_read(socket) for i in 1:len]
    else
        ProtocolException("unexpected type $(Char(magic_byte))") |> throw
    end
end
