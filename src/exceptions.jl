"when the client fail to connect to the server"
immutable ConnectionException <: Exception
    message::AbstractString
end

"when the response from the server doesn't conform to RESP"
immutable ProtocolException <: Exception
    message::AbstractString
end

"when the server returns an error response [http://redis.io/topics/protocol#resp-errors]()"
immutable RedisException <: Exception
    message::AbstractString
end

"when timeout expired"
immutable TimeoutException <: Exception
    message::AbstractString
end
