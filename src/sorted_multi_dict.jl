# A SortedMultiDict is a wrapper around balancedTree.
## Unlike SortedDict, a key in SortedMultiDict can
## refer to multiple data entries.

mutable struct SortedMultiDict{K, D, Ord <: Ordering}
    bt::BalancedTree23{K,D,Ord}

    ## Base constructors

    SortedMultiDict{K,D,Ord}(o::Ord) where {K,D,Ord} = new{K,D,Ord}(BalancedTree23{K,D,Ord}(o))

    function SortedMultiDict{K,D,Ord}(o::Ord, kv) where {K,D,Ord}
        smd = new{K,D,Ord}(BalancedTree23{K,D,Ord}(o))

        if eltype(kv) <: Pair
            # It's (possibly?) more efficient to access the first and second
            # elements of Pairs directly, rather than destructure
            for p in kv
                insert!(smd, p.first, p.second)
            end
        else
            for (k,v) in kv
                insert!(smd, k, v)
            end
        end
        return smd

    end
end

SortedMultiDict() = SortedMultiDict{Any,Any,ForwardOrdering}(Forward)
SortedMultiDict(o::O) where {O<:Ordering} = SortedMultiDict{Any,Any,O}(o)

# Construction from Pairs
SortedMultiDict(ps::Pair...) = SortedMultiDict(Forward, ps)
SortedMultiDict(o::Ordering, ps::Pair...) = SortedMultiDict(o, ps)
SortedMultiDict{K,D}(ps::Pair...) where {K,D} = SortedMultiDict{K,D,ForwardOrdering}(Forward, ps)
SortedMultiDict{K,D}(o::Ord, ps::Pair...) where {K,D,Ord<:Ordering} = SortedMultiDict{K,D,Ord}(o, ps)

# Construction from Associatives
SortedMultiDict(o::Ord, d::Associative{K,D}) where {K,D,Ord<:Ordering} = SortedMultiDict{K,D,Ord}(o, d)

## Construction from iteratables of Pairs/Tuples

# Construction specifying Key/Value types
# e.g., SortedMultiDict{Int,Float64}([1=>1, 2=>2.0])
SortedMultiDict{K,D}(kv) where {K,D} = SortedMultiDict{K,D}(Forward, kv)
function SortedMultiDict{K,D}(o::Ord, kv) where {K,D,Ord<:Ordering}
    try
        SortedMultiDict{K,D,Ord}(o, kv)
    catch e
        if not_iterator_of_pairs(kv)
            throw(ArgumentError("SortedMultiDict(kv): kv needs to be an iterator of tuples or pairs"))
        else
            rethrow(e)
        end
    end
end

# Construction inferring Key/Value types from input
# e.g. SortedMultiDict{}

SortedMultiDict(o1::Ordering, o2::Ordering) = throw(ArgumentError("SortedMultiDict with two parameters must be called with an Ordering and an interable of pairs"))
SortedMultiDict(kv, o::Ordering=Forward) = SortedMultiDict(o, kv)
function SortedMultiDict(o::Ordering, kv)
    try
        _sorted_multidict_with_eltype(o, kv, eltype(kv))
    catch e
        if not_iterator_of_pairs(kv)
            throw(ArgumentError("SortedMultiDict(kv): kv needs to be an iterator of tuples or pairs"))
        else
            rethrow(e)
        end
    end
end

_sorted_multidict_with_eltype(o::Ord, ps, ::Type{Pair{K,D}}) where {K,D,Ord} = SortedMultiDict{  K,  D,Ord}(o, ps)
_sorted_multidict_with_eltype(o::Ord, kv, ::Type{Tuple{K,D}}) where {K,D,Ord} = SortedMultiDict{  K,  D,Ord}(o, kv)
_sorted_multidict_with_eltype(o::Ord, ps, ::Type{Pair{K}}  ) where {K,  Ord} = SortedMultiDict{  K,Any,Ord}(o, ps)
_sorted_multidict_with_eltype(o::Ord, kv, ::Type            ) where {    Ord} = SortedMultiDict{Any,Any,Ord}(o, kv)

## TODO: It seems impossible (or at least very challenging) to create the eltype below.
##       If deemed possible, please create a test and uncomment this definition.
# if VERSION < v"0.6.0-dev.2123"
#     _sorted_multi_dict_with_eltype{  D,Ord}(o::Ord, ps, ::Type{Pair{TypeVar(:K),D}}) = SortedMultiDict{Any,  D,Ord}(o, ps)
# else
#     _include_string("_sorted_multi_dict_with_eltype{  D,Ord}(o::Ord, ps, ::Type{Pair{K,D} where K}) = SortedMultiDict{Any,  D,Ord}(o, ps)")
# end

const SMDSemiToken = IntSemiToken

const SMDToken = Tuple{SortedMultiDict, IntSemiToken}


## This function inserts an item into the tree.
## It returns a token that
## points to the newly inserted item.

@inline function insert!(m::SortedMultiDict{K,D,Ord}, k_, d_) where {K, D, Ord <: Ordering}
    b, i = insert!(m.bt, convert(K,k_), convert(D,d_), true)
    IntSemiToken(i)
end

## push! is an alternative to insert!; it returns the container.


@inline function push!(m::SortedMultiDict{K,D}, pr::Pair) where {K,D}
    insert!(m.bt, convert(K,pr[1]), convert(D,pr[2]), true)
    m
end



## First and last return the first and last (key,data) pairs
## in the SortedMultiDict.  It is an error to invoke them on an
## empty SortedMultiDict.


@inline function first(m::SortedMultiDict)
    i = beginloc(m.bt)
    i == 2 && throw(BoundsError())
    return Pair(m.bt.data[i].k, m.bt.data[i].d)
end

@inline function last(m::SortedMultiDict)
    i = endloc(m.bt)
    i == 1 && throw(BoundsError())
    return Pair(m.bt.data[i].k, m.bt.data[i].d)
end


function searchequalrange(m::SortedMultiDict, k_)
    k = convert(keytype(m),k_)
    i1 = findkeyless(m.bt, k)
    i2, exactfound = findkey(m.bt, k)
    if exactfound
        i1a = nextloc0(m.bt, i1)
        return IntSemiToken(i1a), IntSemiToken(i2)
    else
        return IntSemiToken(2), IntSemiToken(1)
    end
end



## '(k,d) in m' checks whether a key-data pair is in
## a sorted multidict.  This requires a loop over
## all data items whose key is equal to k.


function in_(k_, d_, m::SortedMultiDict)
    k = convert(keytype(m), k_)
    d = convert(valtype(m), d_)
    i1 = findkeyless(m.bt, k)
    i2,exactfound = findkey(m.bt,k)
    !exactfound && return false
    ord = m.bt.ord
    while true
        i1 = nextloc0(m.bt, i1)
        @assert(eq(ord, m.bt.data[i1].k, k))
        m.bt.data[i1].d == d && return true
        i1 == i2 && return false
    end
end




@inline eltype(m::SortedMultiDict{K,D,Ord}) where {K,D,Ord <: Ordering} =  Pair{K,D}
@inline eltype(::Type{SortedMultiDict{K,D,Ord}}) where {K,D,Ord <: Ordering} =  Pair{K,D}
@inline in(pr::Pair, m::SortedMultiDict) =
    in_(pr[1], pr[2], m)
@inline in(::Tuple{Any,Any}, ::SortedMultiDict) =
    throw(ArgumentError("'(k,v) in sortedmultidict' not supported in Julia 0.4 or 0.5.  See documentation"))



@inline keytype(m::SortedMultiDict{K,D,Ord}) where {K,D,Ord <: Ordering} = K
@inline keytype(::Type{SortedMultiDict{K,D,Ord}}) where {K,D,Ord <: Ordering} = K
@inline valtype(m::SortedMultiDict{K,D,Ord}) where {K,D,Ord <: Ordering} = D
@inline valtype(::Type{SortedMultiDict{K,D,Ord}}) where {K,D,Ord <: Ordering} = D
@inline ordtype(m::SortedMultiDict{K,D,Ord}) where {K,D,Ord <: Ordering} = Ord
@inline ordtype(::Type{SortedMultiDict{K,D,Ord}}) where {K,D,Ord <: Ordering} = Ord
@inline orderobject(m::SortedMultiDict) = m.bt.ord

@inline function haskey(m::SortedMultiDict, k_)
    i, exactfound = findkey(m.bt,convert(keytype(m),k_))
    exactfound
end



## Check if two SortedMultiDicts are equal in the sense of containing
## the same (K,D) pairs in the same order.  This sense of equality does not mean
## that semitokens valid for one are also valid for the other.

function isequal(m1::SortedMultiDict, m2::SortedMultiDict)
    ord = orderobject(m1)
    if !isequal(ord, orderobject(m2)) || !isequal(eltype(m1), eltype(m2))
        throw(ArgumentError("Cannot use isequal for two SortedMultiDicts unless their element types and ordering objects are equal"))
    end
    p1 = startof(m1)
    p2 = startof(m2)
    while true
        if p1 == pastendsemitoken(m1)
            return p2 == pastendsemitoken(m2)
        end
        if p2 == pastendsemitoken(m2)
            return false
        end
        k1,d1 = deref((m1,p1))
        k2,d2 = deref((m2,p2))
        if !eq(ord,k1,k2) || !isequal(d1,d2)
            return false
        end
        p1 = advance((m1,p1))
        p2 = advance((m2,p2))
    end
end

const SDorAssociative = Union{Associative,SortedMultiDict}

function mergetwo!(m::SortedMultiDict{K,D,Ord},
                   m2::SDorAssociative) where {K,D,Ord <: Ordering}
    for (k,v) in m2
        insert!(m.bt, convert(K,k), convert(D,v), true)
    end
end

function packcopy(m::SortedMultiDict{K,D,Ord}) where {K,D,Ord <: Ordering}
    w = SortedMultiDict{K,D}(orderobject(m))
    mergetwo!(w,m)
    w
end

function packdeepcopy(m::SortedMultiDict{K,D,Ord}) where {K,D,Ord <: Ordering}
    w = SortedMultiDict{K,D}(orderobject(m))
    for (k,v) in m
        insert!(w.bt, deepcopy(k), deepcopy(v), true)
    end
    w
end


function merge!(m::SortedMultiDict{K,D,Ord},
                others::SDorAssociative...) where {K,D,Ord <: Ordering}
    for o in others
        mergetwo!(m,o)
    end
end

function merge(m::SortedMultiDict{K,D,Ord},
               others::SDorAssociative...) where {K,D,Ord <: Ordering}
    result = packcopy(m)
    merge!(result, others...)
    result
end

function Base.show(io::IO, m::SortedMultiDict{K,D,Ord}) where {K,D,Ord <: Ordering}
    print(io, "SortedMultiDict(")
    print(io, orderobject(m), ",")
    l = length(m)
    for (count,(k,v)) in enumerate(m)
        print(io, k, " => ", v)
        if count < l
            print(io, ", ")
        end
    end
    print(io, ")")
end

similar(m::SortedMultiDict{K,D,Ord}) where {K,D,Ord<:Ordering} =
   SortedMultiDict{K,D}(orderobject(m))

isordered(::Type{T}) where {T<:SortedMultiDict} = true
