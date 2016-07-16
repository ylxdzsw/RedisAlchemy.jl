serializeable(::ANY) = false
serializeable{T<:Integer}(::Type{T}) = true
serializeable{T<:AbstractFloat}(::Type{T}) = true
serializeable{T<:ByteString}(::Type{T}) = true

serialize(x::Integer) = string(x)
serialize(x::AbstractFloat) = string(x)
serialize(x::ByteString) = x

deserialize{T<:Integer}(::Type{T}, x::Bytes) = parse(T, bytestring(x))
deserialize{T<:AbstractFloat}(::Type{T}, x::Bytes) = parse(T, bytestring(x))
deserialize{T<:ByteString}(::Type{T}, x::Bytes) = bytestring(x)
