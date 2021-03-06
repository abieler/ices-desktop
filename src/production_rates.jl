using DataFrames
using Spice
include("io.jl")
include("case_picking.jl")
include("octree.jl")

function case_navg(dataDir, case, df)
  runnames = unique(df[df[:case_name] .== case, :run_name])
  sphereCoords = readcsv("/home/abieler/ices/ices-desktop/work/input/sphere.csv",
                          skipstart=1)[:,4:6]
  nrDensity = zeros(Float64, size(sphereCoords, 1))
  speed = zeros(Float64, size(sphereCoords, 1))
  avgNrDensity = 0.0
  avgSpeed = 0.0
  samplePoint = zeros(Float64, 3)
  println("calc avg number density")
  for run_name in runnames
    @show(run_name)
    oct, nVars, varNames = build_octree(joinpath(dataDir, run_name))
    data = zeros(Float64, nVars)
    for i in 1:size(sphereCoords,1)
      for k in 1:3
        samplePoint[k] = sphereCoords[i,k]
      end
      foundCell, myCell = cell_containing_point(oct, samplePoint)
      if foundCell
        triLinearInterpolation!(myCell, samplePoint, data, 0.0, 0.0, 0.0)
      else
        for k=1:nVars
          data[k] = 0.0
        end
      end
      #sampleDensity = data[1]
      nrDensity[i] = data[1]
      speed[i] = data[5]
    end
    avgNrDensity += mean(nrDensity)
    avgSpeed += mean(speed)
  end
  avgNrDensity /= length(runnames)
  avgSpeed /= length(runnames)
  println("done")
  return avgNrDensity, avgSpeed
end
global const clib = parseUserFile("clibFile:")
metaFile = parseUserFile("kernelFile:")
furnsh(metaFile)

species_str = parseUserFile("species:")
species = [s for s in split(species_str, ',')]

for sp in species
  tFile = "/home/abieler/rosetta/data/dfms/evaluated/timeSeries/tICES.csv"
  #tFile = "../work/input/tDFMS_data.csv"
  run(`julia insitu.jl $tFile`)

  outputDir = joinpath(parseUserFile("workingDir:"), "output")
  dataDir = parseUserFile("dataDir:")
  fileName = "result_" * sp * ".dat"
  df = readtable(joinpath(outputDir, fileName))
  df[:sampleDensity] = zeros(Float64, size(df, 1))
  df[:sampleSpeed] = zeros(Float64, size(df, 1))
  df[:case_name] = Array(AbstractString, size(df, 1))
  for i in 1:size(df, 1)
    df[i, :case_name] = matchall(r"(\d+\.\d+-[\d]{8})", df[i, :run_name])[1]
  end
  case_names = unique(df[:case_name])
  samplePoint = zeros(Float64, 3)
  for case in case_names
    @show(case)
    avgNrDensity, avgSpeed = case_navg(dataDir, case, df)
    df[df[:case_name] .== case, :sampleDensity] = avgNrDensity
    df[df[:case_name] .== case, :sampleSpeed] = avgSpeed
    #=
    runname = joinpath(dataDir, "SHAP5-" * case * "T1200." * sp * ".h5")
    @show(runname)
    oct, nVars, varNames = build_octree(runname)
    data = zeros(Float64, nVars)

    dateStr = matchall(r"(\d{8})", case)[1] * "T2200"
    yy = parse(Int, dateStr[1:4])
    mm = parse(Int, dateStr[5:6])
    dd = parse(Int, dateStr[7:8])
    HH = parse(Int, dateStr[10:11])
    MM = parse(Int, dateStr[12:13])
    t = DateTime(yy,mm,dd,HH,MM)
    et = str2et(string(t))

    # get Sun position and transform from km to m
    r_SUN, lt = spkpos("SUN", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
    r_SUN /= sqrt(r_SUN[1]^2 + r_SUN[2]^2 + r_SUN[3]^2)
    for i=1:3
      samplePoint[i] = r_SUN[i] * 1000. * 20.
    end
    foundCell, myCell = cell_containing_point(oct, samplePoint)
    if foundCell
      triLinearInterpolation!(myCell, samplePoint, data, 0.0, 0.0, 0.0)
    else
      for k=1:nVars
        data[k] = 0.0
      end
    end
    sampleDensity = data[1]
    df[df[:case_name] .== case, :sampleDensity] = sampleDensity
    =#
  end
  df[:corrFactor] = df[:NumberDensity] ./ df[:sampleDensity]
  writetable(joinpath(outputDir, fileName*".extended_speed.new"), df)
end
