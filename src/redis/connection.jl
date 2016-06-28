export RedisConnection, RedisConnectionPool

abstract AbstractRedisConnection

function connect_redis(host::ASCIIString, port::Int, password::ByteString, db::Int)
    connection = connect(host, port)
    # TODO send password and select db
end

type RedisConnection <: AbstractRedisConnection
    socket::TCPSocket
    lock::Condition
    busy::Bool

    RedisConnection(socket) = new(socket, Condition(), false)
end

function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    connect_redis(string(host), port, password, db) |> RedisConnection
end

close(x::RedisConnection) = close(x.socket)
release(x::RedisConnection) = begin
    x.busy = false
    notify(x.lock, all=false)
end
acquire(x::RedisConnection) = begin
    x.busy && wait(x.lock)
    x.busy = true
end

type RedisConnectionPool <: AbstractRedisConnection
    host::ASCIIString
    port::Int
    password::ByteString
    db::Int
    upperbound::Int
    queue::Vector{TCPSocket}
    cond::Condition

    RedisConnectionPool(upperbound=10; host="127.0.0.1", port=6379, password="", db=0) = begin
        new(string(host), port, password, db, upperbound, TCPSocket[], Condition())
    end
end

function new_connection(rcp::RedisConnectionPool)
    push!(rcp.queue, connect_redis(rcp.host, rcp.port, rcp.password, rcp.db))
end

function add_connection(rcp::RedisConnectionPool, socket::TCPSocket)
    push!(rcp.queue, socket)
end

function find_avaliable(rcp::RedisConnectionPool)
    if isempty(rcp.queue)
        if rcp.upperbound > 0
            rcp.upperbound -= 1
            new_connection(rcp)
            find_avaliable(rcp)
        else # wait for one
            wait(rcp.cond)
            find_avaliable(rcp)
        end
    else
        socket = shift!(rcp.queue)
        if socket.status > 4 # drop this and find another
            close(socket)
            rcp.upperbound += 1
            find_avaliable(rcp)
        else
            socket
        end
    end
end
