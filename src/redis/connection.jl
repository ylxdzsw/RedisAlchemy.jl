export RedisConnection, RedisConnectionPool, set_default_redis_connection

abstract type AbstractRedisConnection end

default_connection = nothing

function set_default_redis_connection(x::AbstractRedisConnection=RedisConnection())
    global default_connection = x
end

function connect_redis(host::String, port::Int, password::String, db::Int)
    socket = connect(host, port)
    password != "" && @assert resp_read(resp_send(socket, "auth", password)) == "OK"
    db       != 0  && @assert resp_read(resp_send(socket, "select", "$db")) == "OK"
    socket
end

mutable struct RedisConnection <: AbstractRedisConnection
    socket::TCPSocket
    lock::Condition
    busy::Bool

    RedisConnection(socket) = new(socket, Condition(), false)
end

function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    connect_redis(string(host), port, password, db) |> RedisConnection
end

function acquire(f::Function, rc::RedisConnection)
    rc.busy && wait(rc.lock)
    rc.busy = true
    try
        f(rc.socket)
    finally
        rc.busy = false
        notify(rc.lock, all=false)
    end
end

mutable struct RedisConnectionPool <: AbstractRedisConnection
    host::String
    port::Int
    password::String
    db::Int
    upperbound::Int
    queue::Vector{TCPSocket}
    cond::Condition

    RedisConnectionPool(upperbound=10; host="127.0.0.1", port=6379, password="", db=0) = begin
        new(string(host), port, password, db, upperbound, TCPSocket[], Condition())
    end
end

function find_avaliable(rcp::RedisConnectionPool)
    if isempty(rcp.queue)
        if rcp.upperbound > 0
            rcp.upperbound -= 1
            push!(rcp.queue, connect_redis(rcp.host, rcp.port, rcp.password, rcp.db))
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

function acquire(f::Function, rcp::RedisConnectionPool)
    socket = find_avaliable(rcp)
    try
        f(socket)
    finally
        push!(rcp.queue, socket)
        notify(rcp.cond, all=false)
    end
end
