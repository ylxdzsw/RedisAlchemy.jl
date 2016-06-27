module RedisAlchemy

using OhMyJulia

import Base: getindex, setindex!, wait, start, endof, done, length, chomp!, sum,
             next, keys, values, sort, sort!, show, isempty, ==, |, &, ~, $,
             isnull, close, size, writemime, push!, unshift!, pop!, shift!

include("util.jl")
include("exceptions.jl")

include("redis/client.jl")
include("redis/write.jl")
include("redis/read.jl")

include("collections/bit.jl")
include("collections/list.jl")

end
