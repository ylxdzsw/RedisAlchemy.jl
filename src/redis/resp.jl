"protocol: http://redis.io/topics/protocol"
function resp_send(socket::TCPSocket, commands::ByteString...)
    socket << '*' << length(commands) << CRLF
    for command in commands
        socket << '$' << sizeof(command) << CRLF << command << CRLF
    end
    socket
end

"possible return types: Int64, ByteString, Vector, Void"
function resp_read(socket::TCPSocket)
    magic_byte = socket >> Byte
    line = socket |> readline |> chomp!

    if magic_byte == '+'
        line
    elseif magic_byte == '-'
        RedisException(line) |> throw
    elseif magic_byte == ':'
        parse(Int64, line)
    elseif magic_byte == '$'
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        socket >> (len + 2) |> bytestring |> chomp!
    elseif magic_byte == '*'
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        [resp_read(socket) for i in 1:len]
    else
        ProtocolException("unexpected type $(Char(magic_byte))") |> throw
    end
end
