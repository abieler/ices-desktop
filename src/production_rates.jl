using DataFrames
using Spice
include("io.jl")
include("case_picking.jl")
include("octree.jl")

global const clib = parseUserFile("clibFile:")
metaFile = parseUserFile("kernelFile:")
furnsh(metaFile)

species_str = parseUserFile("species:")
species = [s for s in split(species_str, ',')]

for sp in species
  tFile = "/home/abieler/rosetta/data/dfms/evaluated/timeSeries/tDFMS.dat"
  tFile = "../work/input/tDFMS_data.csv"
  run(`julia insitu.jl $tFile`)

  outputDir = joinpath(parseUserFile("workingDir:"), "output")
  dataDir = parseUserFile("dataDir:")
  fileName = "result_" * sp * ".dat"
  df = readtable(joinpath(outputDir, fileName))
  df[:sampleDensity] = zeros(Float64, size(df, 1))
  df[:case_name] = Array(AbstractString, size(df, 1))
  for i in 1:size(df, 1)
    df[i, :case_name] = matchall(r"\d+\.\d+-[\d]{8}", df[i, :run_name])[1]
  end
  run_names = unique(df[:run_name])
  run_standard_density = Array(Float64, length(run_names))
  samplePoint = zeros(Float64, 3)
  for run in run_names
    oct, nVars, varNames = build_octree(joinpath(dataDir,run))
    data = zeros(Float64, nVars)

    dateStr = matchall(r"(\d{8}T\d{4})", run)[1]
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
    df[df[:run_name] .== run, :sampleDensity] = sampleDensity
  end
  df[:corrFactor] = df[:NumberDensity] ./ df[:sampleDensity]
  writetable(joinpath(outputDir, fileName*".extended"), df)
end
