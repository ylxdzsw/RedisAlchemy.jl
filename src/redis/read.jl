"""
protocol: http://redis.io/topics/protocol#resp-protocol-description
possible return types: Int64, ByteString, Vector, Void
"""
function wait(conn::RedisConnection)
    magic_byte = conn >> Byte
    line = conn |> readline |> chomp!

    if magic_byte == '+'
        line
    elseif magic_byte == '-'
        RedisException(line) |> throw
    elseif magic_byte == ':'
        parse(Int64, line)
    elseif magic_byte == '$'
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        conn >> (len + 2) |> ByteString |> chomp!
    elseif magic_byte == '*'
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        [receive(conn) for i in 1:len]
    else
        ProtocolException("unexpected type $(Char(magic_byte))") |> throw
    end
end
