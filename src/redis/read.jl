"""
protocol: http://redis.io/topics/protocol#resp-protocol-description
possible return types: Int64, ByteString, Vector, Void
"""
function wait(conn::RedisConnection)
    magic_byte = conn.socket >> Byte
    line = conn.socket |> readline |> chomp!

    if magic_byte == '+'
        line
    elseif magic_byte == '-'
        RedisException(line) |> throw
    elseif magic_byte == ':'
        parse(Int64, line)
    elseif magic_byte == '$'
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        conn.socket >> (len + 2) |> bytestring |> chomp!
    elseif magic_byte == '*'
        line[1] == '-' && return nothing
        len = parse(Int64, line)
        [wait(conn) for i in 1:len]
    else
        ProtocolException("unexpected type $(Char(magic_byte))") |> throw
    end
end
