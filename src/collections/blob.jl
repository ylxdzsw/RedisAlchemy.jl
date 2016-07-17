export RedisBlob, SafeRedisBlob

abstract AbstractRedisBlob # <: Bytes

immutable RedisBlob <: AbstractRedisBlob
    conn::AbstractRedisConnection
    key::ByteString
end

RedisBlob(key) = RedisBlob(default_connection, key)

immutable SafeRedisBlob <: AbstractRedisBlob
    conn::AbstractRedisConnection
    key::ByteString
end

SafeRedisBlob(key) = SafeRedisBlob(default_connection, key)

function getindex(rb::AbstractRedisBlob, x::Integer, y::Integer)
    # it is always not null: non-exist keys are treated as empty string by redis
    exec(rb.conn, "getrange", rb.key, zero_index(x), zero_index(y))::Bytes
end

function getindex{T<:Integer}(rb::AbstractRedisBlob, x::UnitRange{T})
    rb[x.start, x.stop]
end

function getindex(rb::AbstractRedisBlob, x::Integer)
    rb[x, x][1]
end

function getindex(rb::RedisBlob, ::Colon=Colon())
    res = exec(rb.conn, "get", rb.key)
    res == nothing && throw(KeyError(rb.key))
    res::Bytes
end

function getindex(rb::SafeRedisBlob, ::Colon=Colon())
    res = exec(rb.conn, "get", rb.key)
    Nullable{Bytes}(res)
end

function setindex!(rb::AbstractRedisBlob, value, offset::Integer)
    exec(rb.conn, "setrange", rb.key, zero_index(offset), value)
    rb
end

function setindex!{T<:Integer}(rb::AbstractRedisBlob, value, x::UnitRange{T})
    value = value |> string |> bytestring
    x.stop - x.start + 1 == sizeof(value) || throw(DimensionMismatch())
    rb[x.start] = value
    rb
end

function setindex!(rb::AbstractRedisBlob, value, ::Colon=Colon())
    exec(rb.conn, "set", rb.key, value)
    rb
end

"this methods should always be used in the form of `rb += xx`"
function (+)(rb::AbstractRedisBlob, value)
    exec(rb.conn, "append", rb.key, value)
    rb
end

function length(rb::AbstractRedisBlob)
    exec(rb.conn, "strlen", rb.key)::Int64
end

function endof(rb::AbstractRedisBlob)
    length(rb)
end

function show(io::IO, rb::AbstractRedisBlob)
    print(io, "RedisBlob($(rb.conn), \"$(rb.key)\")")
end

abstract RedisBlobHandle # <: IO

type BufferedHandle{mode} <: RedisBlobHandle
    rb::RedisBlob
    buffer::IOBuffer

    BufferedHandle(rb) = if mode == :r
        rb = RedisBlob(rb.conn, rb.key)
        new(rb, IOBuffer(rb[]))
    else
        new(rb, IOBuffer())
    end
end

type SeekableHandle{mode} <: RedisBlobHandle
    rb::RedisBlob
    ptr::Int

    SeekableHandle(rb) = begin
        mode == :w && (rb[] = "")
        rb = RedisBlob(rb.conn, rb.key)
        new(rb, 1)
    end
end

function open(rb::RedisBlob, mode="r")
    mode == "r"  ? BufferedHandle{:r}(rb) :
    mode == "w"  ? BufferedHandle{:w}(rb) :
    mode == "a"  ? BufferedHandle{:a}(rb) :
    mode == "r+" ? SeekableHandle{:r}(rb) :
    mode == "w+" ? SeekableHandle{:w}(rb) :
    mode == "a+" ? SeekableHandle{:a}(rb) :
    throw(ArgumentError("unknown mode"))
end

function open(f::Function, rb::RedisBlob, mode="r")
    rbh = open(rb, mode)
    try
        f(rbh)
    finally
        close(rbh)
    end
end

function read(bh::BufferedHandle{:r}, args...)
    read(bh.buffer, args...)
end

function readbytes(bh::BufferedHandle{:r}, args...)
    readbytes(bh, args...)
end

function write(bh::BufferedHandle{:w}, args...)
    write(bh.buffer, args...)
end

function write(bh::BufferedHandle{:a}, args...)
    write(bh.buffer, args...)
end

function flush(bh::BufferedHandle{:w})
    bh.rb[] = bh.buffer.data
end

function flush(bh::BufferedHandle{:a})
    bh.rb += takebuf_array(bh.buffer)
end

function close(bh::BufferedHandle{:r})
    close(bh.buffer)
end

function close(bh::BufferedHandle{:w})
    flush(bh)
    close(bh.buffer)
end

function close(bh::BufferedHandle{:a})
    flush(bh)
    close(bh.buffer)
end

function eof(bh::BufferedHandle)
    eof(bh.buffer)
end

function read(sh::SeekableHandle, T::Type)
    read(sh, T, 1)[1]
end

function read(sh::SeekableHandle, T::Type, dims::Int64...)
    s = *(T.size, dims...)
    buffer = readbytes(sh, s)
    length(buffer) != s && throw(EOFError())
    reinterpret(T, buffer, dims)
end

function readbytes(sh::SeekableHandle, nb::Int)
    nb > 0 || error("invalid Array dimensions")
    buffer = sh.rb[sh.ptr, sh.ptr + nb - 1]
    sh.ptr += length(buffer)
    buffer
end

function readbytes(sh::SeekableHandle)
    buffer = sh.rb[sh.ptr, -1]
    sh.ptr += length(buffer)
    buffer
end

function write(sh::SeekableHandle, bytes::Bytes)
    sh.rb[sh.ptr] = bytes
    sh.ptr += length(bytes)
    length(bytes)
end

function write(sh::SeekableHandle{:a}, bytes::Bytes)
    sh.rb += bytes
    length(bytes)
end

function write(sh::SeekableHandle, args...)
    buffer = IOBuffer()
    write(buffer, args...)
    write(sh, buffer.data)
end

"seek(handle, offset, origin), origin can be on of `:SEEK_SET`, `:SEEK_CUR` and `SEEK_END`"
function seek(sh::SeekableHandle, offset::Int, origin::Symbol=:SEEK_SET)
    len = endof(sh.rb)
    pos = origin == :SEEK_SET ? 1      :
          origin == :SEEK_CUR ? sh.ptr :
          origin == :SEEK_END ? len+1  :
          throw(ArgumentError("unknown origin parameter"))
    pos += offset
    pos = max(pos, 1)
    pos = min(pos, len+1)
    sh.ptr = pos
end

function seekstart(sh::SeekableHandle)
    seek(sh, 0, :SEEK_SET)
end

function seekend(sh::SeekableHandle)
    seek(sh, 0, :SEEK_END)
end

function close(sh::SeekableHandle)
    # do nothing
end

function eof(sh::SeekableHandle)
    sh.ptr > endof(sh.rb)
end

function show{T<:RedisBlobHandle}(io::IO, rbh::T)
    print(io, T, '(')
    show(io, rbh.rb)
    print(io, ')')
end
