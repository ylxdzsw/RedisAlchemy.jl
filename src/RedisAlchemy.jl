module RedisAlchemy

using OhMyJulia

import Base: getindex, setindex!, wait, start, endof, done, length, chomp!, sum,
             next, keys, values, sort, sort!, show, isempty, ==, |, &, ~, $,
             isnull, close, size, writemime, push!, unshift!, pop!, shift!, read,
             write

include("util.jl")
include("exceptions.jl")
include("serializer.jl")

include("redis/client.jl")
include("redis/read.jl")
include("redis/write.jl")

include("collections/bit.jl")
include("collections/list.jl")
include("collections/pipe.jl")

end
