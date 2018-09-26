__precompile__()

module RedisAlchemy

using Sockets
using Serialization

import Base: getindex, setindex!, wait, iterate, lastindex, length, sum,
             keys, values, sort, sort!, show, isempty, ==, |, &, ⊻, ~, +,
             close, size, push!, pushfirst!, pop!, popfirst!, read, write,
             string, seek, seekstart, seekend, eof, flush, open, read!,
             collect, in, wait, notify, resize!, put!, take!

abstract type AbstractRedisCollection end

function show(io::IO, rp::T) where T <: AbstractRedisCollection
    print(io, "$T(\"$(rp.key)\")")
end

include("util.jl")
include("exceptions.jl")
include("serializer.jl")

include("redis/connection.jl")
include("redis/resp.jl")
include("redis/exec.jl")

include("collections/bit.jl")
include("collections/blob.jl")
include("collections/condition.jl")
include("collections/counter.jl")
include("collections/dict.jl")
include("collections/list.jl")
include("collections/pipe.jl")
include("collections/string.jl")

end
