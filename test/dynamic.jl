
function CurrentTimestamp()::Float64
  time()
  end
function BackgroundNoiseWhen(ts::Float64)::Vector{Float64}
  # rng = Random.Xoshiro(ts)
  # rand(rng,Float64,20)
  rand(Float64,20)
  end
function AnotherBackgroundNoise(ts::Float64)::Vector{Float64}
  # rng = Random.MersenneTwister(ts)
  # rand(rng,Float64,20)
  rand(Float64,20)
  end
function SomeEntangle(v1::Vector{Float64}, v2::Vector{Float64})::Vector{Float64}
  return v1 .- v2
  end
function SomeEntangleRenewed(v1::Vector{Float64}, v2::Vector{Float64})::Vector{Float64}
  return v1 .- v2 .+ 10
  end
function SomeStatistic(v::Vector{Float64})::Float64
  return reduce(+,v) / length(v)
  end


@testset "Blaze.jl" begin
  tmpTs = round(Int,time())
  # unit test
  tmpIds = zeros(UInt128,5)
  tmpIds[1] = Blaze.RegisterNeuron("/sys/timestamp", CurrentTimestamp, String[], "desc: level 0")
  tmpIds[2] = Blaze.RegisterNeuron("/var/noise_1", BackgroundNoiseWhen, String["/sys/timestamp"], "level 1, original")
  tmpIds[3] = Blaze.RegisterNeuron("/var/noise_2", AnotherBackgroundNoise, String["/sys/timestamp"], "level 1")
  tmpIds[4] = Blaze.RegisterNeuron("/calc/foobar", SomeEntangle, String["/var/noise_1", "/var/noise_2"], "level 2")
  tmpIds[5] = Blaze.RegisterNeuron("/calc/result", SomeStatistic, String["/calc/foobar"], "level 3")
  # basic
  @test all(map(id->id in collect(values(Blaze.mapNameUUID)),tmpIds))
  @test haskey(Blaze.Motivation, tmpIds[1])
  @test haskey(Blaze.Network,Blaze.mapNameUUID["/calc/foobar"])
  # detail
  @test iszero(Blaze.Detail(tmpIds[1]).NumLevel)
  @test isequal(Blaze.Detail("/calc/result").NumLevel, 3)
  # renew neuron
  sleep(1.3)
  tmpId = Blaze.UpdateNeuron("/var/noise_1", BackgroundNoiseWhen)
  @test !isequal(tmpIds[2], tmpId)
  tmpIds[2] = tmpId
  # trigger motivation
  @test isnothing( Blaze.Trigger(tmpIds[1]) )
  @test isnothing( Blaze.Trigger(SubString["/sys/timestamp","/sys/timestamp"]) )
  @test isnothing( Blaze.Trigger(SubString("/sys/timestampasdf",1:14)) )
  tmpTask = @async Blaze.AutoExecute()
  # upgrade inside runtime
  tmpIds[2] = Blaze.UpdateNeuron("/var/noise_1", BackgroundNoiseWhen, String["/sys/timestamp"], "neuron upgrade test")
  tmpIds[4] = Blaze.UpdateNeuron("/calc/foobar", SomeEntangleRenewed, String["/var/noise_1", "/var/noise_2"], "level 2 renewed")
  wait(tmpTask)
  # continue trigger
  @test Blaze.LastUpdated(tmpIds[5]) > tmpTs
  @test !isnothing(Blaze.Network[tmpIds[5]].Cache[].LastResult[])
  @test typeof(Blaze.View("/calc/result")) == Float64
  for i in 1:5
    @debug i
    @debug Blaze.Network[tmpIds[i]].Base[].UniqueName
    @debug Blaze.Network[tmpIds[i]].Cache[].LastResult[]
  end
  @debug Blaze.Detail("/calc/result")
  end
