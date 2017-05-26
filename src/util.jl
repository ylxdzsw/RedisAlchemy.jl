const CRLF = "\r\n"

const Byte = UInt8
const Bytes = Vector{UInt8}

"zero_index(0) == zero_index(1), not sure if it's OK"
zero_index(x) = ifelse(x > 0, x - 1, x)

"use with caution"
function chomp!(s::Bytes)
    # @assert s[end-1] == '\r' && s[end] == '\n'
    ccall(:jl_array_del_end, Void, (Any, UInt), s, 2)
    return s
end

car(x) = x[1]
cdr(x) = x[2:end]
cadr(x) = x[2]

<<(x::IO, y) = (print(x, y); x)
<<(x::IO, y::Byte) = (write(x, y); x)
<<(x::IO, y::Bytes) = (write(x, y); x)
<<(x::IO, f::Function) = (f(x); x)

>>(x::IO, y) = read(x, y)
>>(x::IO, f::Function) = f(x)
