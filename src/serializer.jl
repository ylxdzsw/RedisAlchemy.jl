serializeable(::Type) = false
serializeable(::Type{<:Integer}) = true
serializeable(::Type{<:AbstractFloat}) = true
serializeable(::Type{<:String}) = true
serializeable(::Type{<:Bytes}) = true

serialize(::Type{T}, x) where T = serialize(T(x))
serialize(x::Integer) = string(x)
serialize(x::AbstractFloat) = string(x)
serialize(x::String) = x
serialize(x::Bytes) = x

deserialize(::Type{T}) where T = x::Bytes -> deserialize(T, x)
deserialize(::Type{T}, x::Bytes) where T <: Integer = parse(T, String(x))
deserialize(::Type{T}, x::Bytes) where T <: AbstractFloat = parse(T, String(x))
deserialize(::Type{T}, x::Bytes) where T <: String = String(x)
deserialize(::Type{T}, x::Bytes) where T <: Bytes = x
