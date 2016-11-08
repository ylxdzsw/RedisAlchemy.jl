serializeable(::ANY) = false
serializeable{T<:Integer}(::Type{T}) = true
serializeable{T<:AbstractFloat}(::Type{T}) = true
serializeable{T<:String}(::Type{T}) = true
serializeable{T<:Bytes}(::Type{T}) = true

serialize(x::Integer) = string(x)
serialize(x::AbstractFloat) = string(x)
serialize(x::String) = x
serialize(x::Bytes) = x

deserialize{T<:Integer}(::Type{T}, x::Bytes) = parse(T, String(x))
deserialize{T<:AbstractFloat}(::Type{T}, x::Bytes) = parse(T, String(x))
deserialize{T<:String}(::Type{T}, x::Bytes) = String(x)
deserialize{T<:Bytes}(::Type{T}, x::Bytes) = x
