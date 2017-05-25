__precompile__()

module RedisAlchemy

import Base: getindex, setindex!, wait, start, endof, done, length, chomp!, sum,
             next, keys, values, sort, sort!, show, isempty, ==, |, &, ~, $, +,
             isnull, close, size, push!, unshift!, pop!, shift!, read, write,
             string, seek, seekstart, seekend, eof, flush, open, read!, collect, in

abstract type AbstractRedisCollection end

include("util.jl")
include("exceptions.jl")
include("serializer.jl")

include("redis/connection.jl")
include("redis/resp.jl")
include("redis/exec.jl")

# include("collections/bit.jl")
# include("collections/blob.jl")
include("collections/counter.jl")
include("collections/dict.jl")
include("collections/list.jl")
include("collections/pipe.jl")
include("collections/string.jl")

end
