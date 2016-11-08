module RedisAlchemy

using OhMyJulia

import Base: getindex, setindex!, wait, start, endof, done, length, chomp!, sum,
             next, keys, values, sort, sort!, show, isempty, ==, |, &, ~, $, +,
             isnull, close, size, writemime, push!, unshift!, pop!, shift!, read,
             write, string, seek, seekstart, seekend, readall, readbytes, eof,
             flush, open, read!, readbytes!, collect, in

include("util.jl")
include("exceptions.jl")
include("serializer.jl")

include("redis/connection.jl")
include("redis/resp.jl")
include("redis/exec.jl")

include("collections/bit.jl")
include("collections/blob.jl")
include("collections/dict.jl")
include("collections/list.jl")
include("collections/pipe.jl")
include("collections/string.jl")

end
