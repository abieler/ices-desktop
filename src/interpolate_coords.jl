using Spice

include("io.jl")
include("octree.jl")
include("raytrace.jl")


global const clib = parseUserFile("clibFile:")
global const species = parseUserFile("species:")
if length(split(species, ',')) != 1
  println(" - Please define exactly one species in .userSettings.conf")
  exit()
end

coordFileName = ARGS[1]
metaFile = parseUserFile("kernelFile:")
try
  furnsh(metaFile)
catch e
  println("spice error")
  println(e)
  exit()
end

const fileName = parseUserFile("dataFile:")
const filePath = dirname(fileName)
fileNameExtension = split(basename(fileName), ".")[end]
fileNameBase = basename(fileName)[1:end-(length(fileNameExtension)+1)]


oct, nVars, varNames = build_octree(filePath, fileNameBase)
dummyCell = Cell(zeros(3),
                 zeros(3),
                 zeros(8,3),
                 0.0,
                 zeros(2,2),
                 false,
                 Triangle[],
                 0)
oct.cells[1] = dummyCell

println(" - nVars : ", nVars)
coords = load_user_coordinates(coordFileName, 3)
#coords = coords[4:6,:]

@time result = interpolate(nVars, coords, oct)
save_interpolation_results(nVars, result, coords, "interp_output.$species.dat")
