using HDF5, JLD
using PyPlot
using Spice
using Instrument

include("io.jl")
include("octree.jl")
include("case_picking.jl")
@everywhere include("raytrace.jl")

global const clib = parseUserFile("clibFile:")
println(" - start")
metaFile = parseUserFile("kernelFile:")
try
  furnsh(metaFile)
catch e
  println("spice error")
  println(e)
  exit()
end

if length(ARGS) == 1
  instrumentName = ARGS[1]
  instrument = rosetta_instruments[instrumentName]
  nPixelsX = instrument.nPixelsX
  nPixelsY = instrument.nPixelsY
  phiX = instrument.phiX
  phiY = instrument.phiY
else
  nPixelsX = parse(Int, ARGS[2])
  nPixelsY = parse(Int, ARGS[3])
  phiX = parse(Float64, ARGS[4])
  phiY = parse(Float64, ARGS[5])

  rotMat = eye(3)
end

const meshFile = parseUserFile("meshFile:")
const doCheckShadow = parseUserFile("doCheckShadow:")

if contains(doCheckShadow, "y")
  doCheckShadow_bool = true
else
  doCheckShadow_bool = false
end

doBlankBody = false
userStr = lowercase(parseUserFile("pltBlankBody:"))
if contains(userStr, "true") || contains(userStr, "yes")
  doBlankBody = true
else
  doBlankBody = false
end

t = DateTime(2015,7,15)
tStop = DateTime(2015,9,15)
dt = Dates.Minute(10)

while t < tStop
    etStr = string(t)
    et = str2et(etStr)
    rotMat = pxform(instrument.frame, "67P/C-G_CK", et)
    rotMat = rotMat'
    fileName = select_data_file(et, etStr)
    @show(fileName)
    filePath = dirname(fileName)
    fileNameExtension = split(basename(fileName), ".")[end]
    fileNameBase = basename(fileName)[1:end-(length(fileNameExtension)+1)]

    ################################################################################
    # load data from spice
    rRos_km, lt = spkpos("ROSETTA", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
    println(" - observer distance from coordinate center : ", norm(rRos_km), " km")
    rStart = rRos_km .* 1000

    ################################################################################
    # create pointing vectors
    lx = 2 * sin(phiX / 180.0 * pi)
    ly = 2 * sin(phiY / 180.0 * pi)

    rPointing = ones(Float64, 3, nPixelsX * nPixelsY)
    z = 1.0
    k = 1
    for (j,y) = enumerate(linspace(-ly / 2.0, ly / 2.0, nPixelsY))
      for (i,x) = enumerate(linspace(-lx / 2.0, lx / 2.0, nPixelsX))
        norm_rPointing = sqrt(x*x + y*y + z*z)
        rPointing[1,k] = x / norm_rPointing
        rPointing[2,k] = y / norm_rPointing
        rPointing[3,k] = z / norm_rPointing
        k += 1
      end
    end

    # rotate pointing vectors to comet centric frame
    for k=1:nPixelsX*nPixelsY
      rPointing[:,k] = rotMat * vec(rPointing[:,k])
    end

    oct, nVars, varNames = build_octree(filePath, fileNameBase)
    println(" - nVars : ", nVars)
    nTriangles, allTriangles, totalSurfaceArea = load_ply_file(meshFile)

    assign_triangles!(oct, allTriangles)
    println(" - performing LOS calculations, please wait...")
    @time ccd, mask = doIntegration(oct, rPointing, rStart, nVars, allTriangles,
                              doCheckShadow_bool, fileName)

    save_result(ccd, mask, nVars, varNames, nPixelsX, nPixelsY, etStr)
    if false
        try
          plot_result(ccd, mask, nVars, nPixelsX, nPixelsY)
        catch
        end
    end
    previousDir = pwd()
    wrkDir = parseUserFile("workingDir:")
    cd(joinpath(wrkDir, "output"))
    writedlm("ccd.dat", ccd)
    cd(previousDir)
    t += dt
end
