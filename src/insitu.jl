using Spice
include("io.jl")
include("case_picking.jl")
include("octree.jl")

type Run
  case::AbstractString
  species::AbstractString
  nVars::Int
  variables::Vector{AbstractString}
  date::Vector{DateTime}
  r_SC::Vector{Float64}
  data::Vector{Float64}
  delta_lat::Vector{Float64}
  delta_lon::Vector{Float64}
end

function run_index(runs, caseName)
  for i=1:length(runs)
    if caseName == runs[i].case
      return i
    end
  end
  return -1
end

tt = DateTime[]

if length(ARGS) == 3
  t = DateTime(ARGS[1])
  tStop = DateTime(ARGS[2])
  dt = Dates.Second(parse(Int,ARGS[3]))
  while t < tStop
    push!(tt, t)
    t += dt
  end
elseif length(ARGS) == 1
  fileName = ARGS[1]
  fid = open(fileName, "r")
  while !eof(fid)
    try
      tStr = readline(fid)
      push!(tt, DateTime(tStr))
    catch
      println(" - Could not recognize date format of: ", tStr)
      println(" - Please use format such as: 2015-04-25T00:00:00")
      close(fid)
      exit()
    end
  end
  close(fid)
else
  println(" - Must provide either 1 or 3 arguments when starting script.")
  exit()
end




const species = split(parseUserFile("species:"), ',')
const nSpecies = length(species)

global const clib = parseUserFile("clibFile:")

@show(species)

metaFile = parseUserFile("kernelFile:")
furnsh(metaFile)

const dataDir = parseUserFile("dataDir:")

runs = Run[]
df_runs = build_df(dataDir)


#while t < tStop
for t in tt
  et = str2et(string(t))

  # get SC position and transform from km to m
  r_SC, lt = spkpos("ROSETTA", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
  for i=1:3
    r_SC[i] *= 1000.0
  end

  for sp in species
    myCase, dlat, dlon = select_data_file(df_runs, et, sp)
    iRun = run_index(runs, myCase)
    if iRun > 0
      push!(runs[iRun].date, t)
      push!(runs[iRun].delta_lat, dlat)
      push!(runs[iRun].delta_lon, dlon)
      append!(runs[iRun].r_SC, r_SC)
    elseif iRun == -1
      push!(runs, Run(myCase, sp, 0, AbstractString[], DateTime[t], copy(r_SC), Float64[], Float64[dlat], Float64[dlon]))
    end
  end
end

samplePoint = zeros(Float64, 3)
for run in runs
  oct, nVars, varNames = build_octree(run.case)
  run.variables = varNames
  run.nVars = nVars
  data = zeros(Float64, nVars)
  nPoints = length(run.date)
  @show(run.case)
  @show(varNames)
  @show(nPoints)
  println()
  coords = reshape(run.r_SC, (3,nPoints))
  for i=1:nPoints
    for k=1:3
      samplePoint[k] = coords[k,i]
    end
    foundCell, myCell = cell_containing_point(oct, samplePoint)
    if foundCell
      triLinearInterpolation!(myCell, samplePoint, data, 0.0, 0.0, 0.0)
    else
      for k=1:nVars
        data[k] = 0.0
      end
    end
    append!(run.data, data)
  end
  rundata = reshape(run.data, (nVars,nPoints))
end


save_insitu_results(runs, species)
