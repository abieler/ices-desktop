using Spice
include("io.jl")
include("case_picking.jl")
include("octree.jl")


# construct array of time instances where data will be calculated.
tt = time_period(ARGS)

const species = split(parseUserFile("species:"), ',')
const nSpecies = length(species)
global const clib = parseUserFile("clibFile:")
#metaFile = parseUserFile("kernelFile:")
#furnsh(metaFile)
furnsh("/home/abieler/ices/ices-desktop/spiceKernels/metafiles/operationalKernels.tm")
const dataDir = parseUserFile("dataDir:")


runs = Run[]
df_runs = build_df(dataDir)

# for each time step calculate position of the Sun and pick the best fitting
# dsmc case for that position. Then compute coordinates of the Rosetta and assign
# those coordinates to the selected Run. This way all coordinates are sorted
# to the corresponding Runs. A run is a specific simulation result from AMPS
# (one output file from AMPS = a Run)

for (iii, t) in enumerate(tt)
  et = str2et(string(t))
  # get SC position and transform from km to m
  r_SC, lt = spkpos("ROSETTA", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
  for i=1:3
    r_SC[i] *= 1000.0
  end

  for sp in species
    myRun, dlat, dlon = select_data_file(df_runs, et, string(t), sp)
    iRun = run_index(runs, myRun)
    if iRun > 0
      push!(runs[iRun].date, t)
      push!(runs[iRun].delta_lat, dlat)
      push!(runs[iRun].delta_lon, dlon)
      append!(runs[iRun].r_SC, r_SC)
    elseif iRun == -1
      push!(runs, Run(myRun, sp, 0, AbstractString[], DateTime[t], copy(r_SC), Float64[], Float64[dlat], Float64[dlon]))
    end
  end
end

samplePoint = zeros(Float64, 3)
for run in runs
  oct, nVars, varNames = build_octree(run.case)
  run.variables = varNames
  run.nVars = nVars
  @show(run.variables)
  @show(run.nVars)
  data = zeros(Float64, nVars)
  nPoints = length(run.date)
  @show(run.case)
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
