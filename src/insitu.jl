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
end

function run_index(runs, caseName)
  for i=1:length(runs)
    if caseName == runs[i].case
      return i
    end
  end
  return -1
end


t = DateTime(ARGS[1])
tStop = DateTime(ARGS[2])
dt = Dates.Second(parse(Int,ARGS[3]))

const species = split(parseUserFile("species:"), ',')
const nSpecies = length(species)

global const clib = parseUserFile("clibFile:")

@show(species)

metaFile = parseUserFile("kernelFile:")
furnsh(metaFile)

const dataDir = parseUserFile("dataDir:")

runs = Run[]
df_runs = build_df(dataDir)

while t < tStop
  et = str2et(string(t))

  # get SC position and transform from km to m
  r_SC, lt = spkpos("ROSETTA", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
  for i=1:3
    r_SC[i] *= 1000.0
  end

  for sp in species
    myCase = select_data_file(df_runs, et, sp)
    iRun = run_index(runs, myCase)
    if iRun > 0
      push!(runs[iRun].date, t)
      append!(runs[iRun].r_SC, r_SC)
    elseif iRun == -1
      push!(runs, Run(myCase, sp, 0, AbstractString[], DateTime[t], copy(r_SC), Float64[]))
    end
  end
  t += dt
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

for sp in species
  firstFound = false
  nVars = 0
  varNames = AbstractString[]
  for i in 1:length(runs)
    if (runs[i].species == sp)
      if firstFound == false
        alldata = reshape(runs[i].data, (runs[i].nVars, length(runs[i].date)))
        alldates = runs[i].date
        nVars = runs[i].nVars
        varNames = runs[i].variables
        firstFound = true
      else
        alldata = hcat(alldata, reshape(runs[i].data, (runs[i].nVars, length(runs[i].date))))
        append!(alldates, runs[i].date)
      end
    end
  end

  sortIndex = sortperm(alldates)
  alldates = alldates[sortIndex]
  alldata = alldata[:,sortIndex]

  fid = open("result_" * sp * ".dat", "w")
  write(fid, "date,")
  for i=1:nVars-1
    write(fid, varNames[i], ",")
  end
  write(fid, varNames[end], "\n")
  for i=1:length(alldates)
    write(fid, string(alldates[i]), ",")
    for k=1:nVars-1
      write(fid, string(alldata[k,i]), ",")
    end
    write(fid, string(alldata[nVars,i]), "\n")
  end
  close(fid)
end
