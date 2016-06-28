RedisAlchemy.jl
===============

RedisAlchemy.jl provides some "high-level" collections connected to a a Redis server.

inspired by [Redis.jl](https://github.com/jkaye2012/Redis.jl).

### Install

```
Pkg.clone("git@github.com:ylxdzsw/RedisAlchemy.jl.git","RedisAlchemy")
```

### Connections

RedisAlchemy.jl provides two connection type: `RedisConnection` and `RedisConnectionPool`.

```
conn = RedisConnection(host="127.0.0.1", port=6379, password="", db=0)
connpool = RedisConnectionPool(10, host="127.0.0.1", port=6379, password="", db=0)
```

the first argument of `RedisConnectionPool` is the max connection number. All the arguments above are the default value, which can be ommited.

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

### Safe Versions

Almost every redis collection has a coresponding "safe" version, which provides exactly the same API, but return a Nullable rather than throw Exceptions if key not exists.
