export RedisConnection

immutable RedisConnection <: IO
    socket::TCPSocket
end

function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    connection = connect(host, port) |> RedisConnection
    # TODO send password and select db
end

close(x::RedisConnection) = close(x.socket)
status(x::RedisConnection) = x.socket.status
write(x::RedisConnection, y) = write(x.socket, y)
read(x::RedisConnection, y) = read(x.socket, y)
readbytes(x::RedisConnection, y) = readbytes(x.socket, y)
