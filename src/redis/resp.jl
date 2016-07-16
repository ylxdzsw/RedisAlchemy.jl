#protocol: http://redis.io/topics/protocol

"`commands` can be any thing that `write` and `sizeof` works properly"
function resp_send(socket::TCPSocket, commands...)
    buffer = IOBuffer() # use buffer to circumvent the overhead of thread swithcing of network IO
    buffer << '*' << length(commands) << CRLF
    for command in commands
        buffer << '$' << sizeof(command) << CRLF << command << CRLF
    end
    write(socket, seekstart(buffer))
    socket
end

"possible return types: Int64, Bytes, Vector, Void"
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

#== helpers ==#

"read until CRLF, exlusive the trailling CRLF, throw EOFError() when not found CRLF"
function readuntilCRLF(s::IO)
    out = IOBuffer()
    state = 0x00 # 0x00: not found, 0x01: found \r
    while true
        c = s >> Byte
        if state == 0x00
            if c == '\r'
                state = 0x01
            else
                out << c
            end
        else # state == 0x01
            if c == '\n'
                return seekstart(out)::IOBuffer
            elseif c == '\r'
                out << '\r'
            else
                state = 0x00
                out << '\r' << c
            end
        end
    end
end

"use with caution"
function chomp!(s::Bytes)
    # @assert s[end-1] == '\r' && s[end] == '\n'
    ccall(:jl_array_del_end, Void, (Any, UInt), s, 2)
    return s
end
