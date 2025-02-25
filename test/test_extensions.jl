module TestExtensions
using Test
using Accessors
using AxisKeys
using IntervalSets
using StaticArrays, StaticNumbers
using StructArrays


# most of the tests run on Julia 1.9 and later because of package extensions support
# StaticArrays is the exception: it's supported on earlier Julia versions with Requires


VERSION >= v"1.9-" && @testset "AxisKeys" begin
    A = KeyedArray([1 2 3; 4 5 6], x=[:a, :b], y=11:13)

    for B in (
        @set(axiskeys(A)[2] = [:y, :z, :w]),
        @set(named_axiskeys(A).y = [:y, :z, :w]),
        @set(A |> axiskeys(_, 2) = [:y, :z, :w]),
        @set(A |> axiskeys(_, :y) = [:y, :z, :w]),
    )
        @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
        @test named_axiskeys(B) == (x=[:a, :b], y=[:y, :z, :w])
    end

    B = @set named_axiskeys(A) = (a=[1, 2], b=[3, 2, 1])
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (a=[1, 2], b=[3, 2, 1])

    B = @set dimnames(A) = (:a, :b)
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (a=[:a, :b], b=11:13)

    B = @set AxisKeys.keyless_unname(A) = [6 5 4; 3 2 1]
    @test named_axiskeys(B) == named_axiskeys(A)
    @test AxisKeys.keyless_unname(B) == [6 5 4; 3 2 1]

    B = @set vec(A) = 1:6
    @test AxisKeys.keyless_unname(B) == [1 3 5; 2 4 6]
    @test named_axiskeys(B) == named_axiskeys(A)

    @test_throws ArgumentError @set axiskeys(A)[1] = 1:3
    @test_throws ArgumentError @set named_axiskeys(A).x = 1:3
    @test_throws Exception     @set axiskeys(A) = ()
    @test_throws ArgumentError @set named_axiskeys(A) = (;)
end

VERSION >= v"1.9-" && @testset "IntervalSets" begin
    int = Interval{:open, :closed}(1, 5)

    @test Interval{:open, :closed}(1, 10) === @set int.right = 10
    @test Interval{:open, :closed}(10.0, 11.0) === @set endpoints(int) = (10.0, 11.0)
    @test Interval{:open, :closed}(-2, 5) === @set leftendpoint(int) = -2
    @test Interval{:open, :closed}(1, 2) === @set rightendpoint(int) = 2
    @test Interval{:closed, :closed}(1, 5) === @set first(closedendpoints(int)) = true
    Accessors.test_getset_laws(endpoints, int, (10, 11), (-3, 2))
    Accessors.test_getset_laws(closedendpoints, int, (true, true), (true, false))
    Accessors.test_getset_laws(leftendpoint, int, 2, 3)
    Accessors.test_getset_laws(rightendpoint, int, 2, 3)

    @test 1 === @set 2 |> mod(_, 0..3) = 1
    @test 31 === @set 32 |> mod(_, 0..3) = 1
    @test 2 === @set 2 |> mod(_, 20..23) = 20
    @test 33 === @set 32 |> mod(_, 20..23) = 21
    Accessors.test_getset_laws(@optic(mod(_, 5..8)), 20, 6, 5)
end

@testset "StaticArrays" begin
    obj = StaticArrays.@SMatrix [1 2; 3 4]
    @testset for l in [
            (@optic _[2,1]),
        ]
        @test l(obj) === 3
        @test set(obj, l, 5)         === StaticArrays.@SMatrix [1 2; 5 4]
        @test setindex(obj, 5, 2, 1) === StaticArrays.@SMatrix [1 2; 5 4]
    end

    v = @SVector [1.,2,3]
    @test (@set v[1] = 10) === @SVector [10.,2,3]
    @test (@set v[1] = π) === @SVector [π,2,3]
    # requires ConstructionBase extension:
    VERSION >= v"1.9-DEV" && @test (@set v.x = 10) === @SVector [10.,2,3]

    @testset "Multi-dynamic indexing" begin
        two = 2
        plusone(x) = x + 1
        l1 = @optic _.a[2, 1].b
        l2 = @optic _.a[plusone(end) - two, end÷2].b
        m_orig = @SMatrix [
            (a=1, b=10) (a=2, b=20)
            (a=3, b=30) (a=4, b=40)
            (a=5, b=50) (a=6, b=60)
        ]
        m_mod = @SMatrix [
            (a=1, b=10) (a=2, b=20)
            (a=3, b=3000) (a=4, b=40)
            (a=5, b=50) (a=6, b=60)
        ]
        obj = (a=m_orig, b=4)
        @test l1(obj) === l2(obj) === 30
        @test set(obj, l1, 3000) === set(obj, l2, 3000) === (a=m_mod, b=4)
    end

    v = @set StaticArrays.normalize(@SVector [10, 0,0]) = @SVector[0,1,0]
    @test v ≈ @SVector[0,10,0]
    @test @set(StaticArrays.norm([1,0]) = 20) ≈ [20, 0]
end


struct S{TA, TB}
    a::TA
    b::TB
end

VERSION >= v"1.9-" && @testset "StructArrays" begin
    s = StructArray(([1, 2, 3],))
    ss = @set s.:1 = 10:12
    @test ss.:1 === 10:12
    sb = @insert s.:2 = 10:12
    @test sb.:1 === s.:1
    @test sb.:2 === 10:12
    ss = @delete sb.:2
    @test ss.:1 === s.:1

    s = StructArray(a=[1, 2, 3])
    sb = @insert StructArrays.components(s).b = 10:12
    @test sb.a === s.a
    @test sb.b === 10:12
    sb = @insert s.b = 10:12
    @test sb.a === s.a
    @test sb.b === 10:12
    sa = @set sb.a = 1:3
    @test sa.a === 1:3
    @test sa.b === sb.b
    @test_throws ArgumentError @set sb.c = 1:3
    sd = @delete sb.a
    @test sd::StructArray == StructArray(b=10:12)
    @test_throws "only eltypes with fields" @delete s.a

    s = StructArray([(a=(x=1, y=:abc),), (a=(x=2, y=:def),)]; unwrap=T -> T <: NamedTuple)
    @test @set(s.a = 10:12)::StructArray == StructArray(a=10:12)
    @test @set(s.a.x = 10:11)::StructArray == [(a=(x=10, y=:abc),), (a=(x=11, y=:def),)]
    @test @insert(s.b = 10:11)::StructArray == [(a=(x=1, y=:abc), b=10), (a=(x=2, y=:def), b=11)]
    @test @insert(s.a.z = 10:11)::StructArray == [(a=(x=1, y=:abc, z=10),), (a=(x=2, y=:def, z=11),)]
    @test @delete(s.a.y)::StructArray == [(a=(x=1,),), (a=(x=2,),)]

    s = StructArray([S(1, 2), S(3, 4)])
    @test @inferred(set(s, PropertyLens(:a), 10:11))::StructArray == StructArray([S(10, 2), S(11, 4)])
    @test @inferred(set(s, PropertyLens(:a), [:a, :b]))::StructArray == StructArray([S(:a, 2), S(:b, 4)])
end

end
