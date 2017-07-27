export RedisCondition

mutable struct RedisCondition{T}
    key::String
    socket::IO
    listen::Bool

    RedisCondition{T}(channel::AbstractString) where T = RedisCondition{T}(default_connection, channel)

    RedisCondition{T}(rc::RedisConnection, key) where T = if serializeable(T)
        rc.busy && wait(rc.lock)
        rc.busy = true

        c = new{T}(key, rc.socket, false)

        finalizer(c, (x)->try
            c.listen && resp_send(rc.socket, "unsubscribe", key) |> resp_read
        finally
            rc.busy = false
            notify(rc.lock, all=false)
        end)

        c
    else
        throw(ArgumentError("RedisCondition currently not supports arbitrary element type"))
    end

    RedisCondition{T}(rcp::RedisConnectionPool, key) where T = if serializeable(T)
        socket = find_avaliable(rcp)

        c = new{T}(key, socket, false)

        finalizer(c, (x)->try
            c.listen && resp_send(socket, "unsubscribe", key) |> resp_read
        finally
            push!(rcp.queue, socket)
            notify(rcp.cond, all=false)
        end)

        c
    else
        throw(ArgumentError("RedisCondition currently not supports arbitrary element type"))
    end
end

RedisCondition(args...) = RedisCondition{String}(args...)

function wait(rc::RedisCondition{T}) where T
    if !rc.listen
        resp_send(rc.socket, "subscribe", rc.key) |> resp_read
        rc.listen = true
    end
    _, _, x = resp_read(rc.socket)
    deserialize(T, x)
end

"wake up all"
function notify(rc::RedisCondition{T}, val="") where T
    if rc.listen
        error("cannot notify a listening condition")
    end
    resp_send(rc.socket, "publish", rc.key, serialize(T, val)) |> resp_read
end
