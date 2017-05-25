"when the client fail to connect to the server"
struct ConnectionException <: Exception
    message::AbstractString
end

"when the response from the server doesn't conform to RESP"
struct ProtocolException <: Exception
    message::AbstractString
end

"when the server returns an error response [http://redis.io/topics/protocol#resp-errors]()"
struct RedisException <: Exception
    message::AbstractString
end

"when timeout expired"
struct TimeoutException <: Exception
    message::AbstractString
end
