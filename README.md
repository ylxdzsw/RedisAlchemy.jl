RedisAlchemy.jl
===============

RedisAlchemy.jl provides some "high-level" collections connected to a Redis server.

inspired by [Redis.jl](https://github.com/jkaye2012/Redis.jl).

key features:

- easy to use: "high-level" API like native Julia Collection, no need to learn Redis.
- ready for async: connections are locked automaticlly; support connection pools.

### Installation

```
Pkg.clone("git@github.com:ylxdzsw/RedisAlchemy.jl.git","RedisAlchemy")
```

### Connections

RedisAlchemy.jl provides two connection type: `RedisConnection` and `RedisConnectionPool`. They are interchangeable in all APIs.

```
conn = RedisConnection(host="127.0.0.1", port=6379, password="", db=0)
connpool = RedisConnectionPool(10, host="127.0.0.1", port=6379, password="", db=0)
```

the first argument of `RedisConnectionPool` is the max connection number. All the arguments above are the defaults, thus can be ommited.

In most cases, you don't have to use the connection pool. However, when using `RedisPipe` or somthing like this, which blocks the socket, you must use pools to circumvent dead locks.

### List

`RedisList{T}` provides an API that close to the Julia's `Vector{T}`, so you might be familiar with it.

```
julia> list = RedisList{Int}(conn, "testlist")
RedisList{Int64}(RedisAlchemy.RedisConnection(TCPSocket(open, 0 bytes waiting),Condition(Any[]),false), "testlist")

julia> list[:]
0-element Array{Int64,1}

julia> push!(list, 2)
RedisList{Int64}(RedisAlchemy.RedisConnection(TCPSocket(open, 0 bytes waiting),Condition(Any[]),false), "testlist")

julia> unshift!(list, 3)
RedisList{Int64}(RedisAlchemy.RedisConnection(TCPSocket(open, 0 bytes waiting),Condition(Any[]),false), "testlist")

julia> length(list)
2

julia> list[1:2]
2-element Array{Int64,1}:
 3
 2

julia> sort!(list)
2

julia> list[:]
2-element Array{Int64,1}:
 2
 3
```

Tips:

- `RedisList` also support negative index, which means `end-x` in julia. You can use it in the form like `list[0, -1]`. This is considered faster and more reliable than `end-x`, because the latter use an extra query to get the length.
- Don't use `while !isempty(list) pop!(list)` pattern, use `SafeRedisList` and `pop!` it directly, then check if the returned value is null.
- `RedisList` was considered as `queue` or `stack`, rather than random-access array. If you want to save a series of fixed-length elements (like time series), try `RedisBlob`

### Blob

`RedisBlob` can be used to save binary files or array.

```
julia> r = RedisBlob(conn, "testarray")
RedisBlob(RedisAlchemy.RedisConnectionPool("127.0.0.1",6379,"",0,9,[TCPSocket(open, 0 bytes waiting)],Condition(Any[])), "testarray")

julia> a = rand(1:100, 4, 4)
4x4 Array{Int64,2}:
 41  38  17  55
 12  81  71  43
 58  54  80  92
 59  82  27  52

julia> r[] = reinterpret(UInt8, a, (4 * 4 * 8,))
128-element Array{UInt8,1}:
 ...

julia> b = reinterpret(Int, r[], (4, 4))
4x4 Array{Int64,2}:
 41  38  17  55
 12  81  71  43
 58  54  80  92
 59  82  27  52

# read a specific element
julia> open(r, "r+") do f
         seek(f, (sub2ind((4,4), 2, 2) - 1) * 8) # `seek` counts from 0
         read(f, Int) |> println
       end
81
```

### Safe Versions

Almost every redis collection has a coresponding "safe" version, which provides exactly the same API, but return a Nullable rather than throw Exceptions if key not exists.

### Serialize

RedisAlchemy collections only support subtypes of `ByteString`, `Integer` and `AbstractFloat` as elements. To store arbitrary elements in RedisAlchemy collections, you need to implement `serializeable`, `serialize` and `deserialize` for the element type. Here is an example shows how to do it.

```
immutable Point{T<:Integer}
    x::T
    y::T
end

# 1: set serializeable return true for that type
RedisAlchemy.serializeable{T<:Integer}(::Type{Point{T}}) = true

# 2: serialize takes an argument of that type, and returns either a ByteString or a Vector{UInt8}
RedisAlchemy.serialize{T<:Integer}(p::Point{T}) = string(p.x, ',', p.y)

# 3: deserialize takes Vector{UInt8} as input, recovers the origin element
RedisAlchemy.deserialize{T<:Integer}(::Type{Point{T}}, s::Vector{UInt8}) = begin
    s = split(bytestring(s), ',')
    x = parse(T, s[1])
    y = parse(T, s[2])
    Point{T}(x, y)
end

# now you can make RedisAlchemy collections of that type.
points = RedisList{Point{Int64}}(conn, "key")
```

You can make use of `Base.serialize` and `Base.deserialize` to implement these methods. However, They are hard to be read by other programs, even by Julia of different versions. So instead we suggest use self-explanatory string representations.

### Direct Access

Sometimes you may want to access the underlying Redis directly, RedisAlchemy.jl provides a `exec` API to run simple commands.

```
res = exec(conn, "rpoplpush", "list1", "list2")
```

The responsed type is one of `Int64`, `ByteString`, `Vector`, `Vector{UInt8}` and `Void`.
