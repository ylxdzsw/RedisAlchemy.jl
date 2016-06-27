module RedisAlchemy

using OhMyJulia

import Base: getindex, setindex!, wait, start, endof, done, length, chomp!, sum,
             next, keys, values, sort, sort!, show, isempty, ==, |, &, ~, $,
             isnull,

include("util.jl")
include("exceptions.jl")

include("redis/client.jl")
include("redis/write.jl")
include("redis/read.jl")

include("collections/bitvector.jl")

end
