const CRLF = "\r\n"

"zero_index(0) == zero_index(1), not sure if it's OK"
zero_index(x) = x > 0 ? x - 1 : x

"use with caution"
function chomp!(s::Bytes)
    # @assert s[end-1] == '\r' && s[end] == '\n'
    ccall(:jl_array_del_end, Void, (Any, UInt), s, 2)
    return s
end
