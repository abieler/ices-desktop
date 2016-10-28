using Spice
using FileIO
using WriteVTK

include("io.jl")
include("octree.jl")
@everywhere include("raytrace.jl")


function angle_btw_vec(v1::Array{Float64,1}, v2::Array{Float64,1})
  if (v1 == v2)
      return 0.0
  end
  acos(dot(v1, v2))
end

println(" - start")
metaFile = parseUserFile("kernelFile:")
try
  furnsh(metaFile)
catch e
  println("spice error")
  println(e)
  exit()
end

etStr = ARGS[1]
et = str2et(etStr)

const meshFile = parseUserFile("meshFile:")
rSun_km, lt = spkpos("SUN", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
rSun_hat = rSun_km / norm(rSun_km)

nTriangles, allTriangles, totalSurfaceArea = load_ply_file(meshFile)
oct = octree_only()
#assign_triangles!(oct, allTriangles)
triangles_to_cells!(oct, allTriangles)

triInCells = 0
for cell in oct.cells
  triInCells += length(cell.triangles)
end

@show(nTriangles)
@show(triInCells)
readline(STDIN)

cos_sza = zeros(nTriangles)
isInShadow = falses(nTriangles)
for (i, tri) in enumerate(allTriangles)
  cos_sza[i] = cos(angle_btw_vec(tri.surfaceNormal, rSun_hat))
  if cos_sza[i] <= 0
    isInShadow[i] = true
  else
    pos = copy(tri.center)
    pos .+= (2*eps()) .* tri.surfaceNormal
    oldCenter = rand(3)
    didFind, mycell = cell_containing_point(oct, pos)
    while !is_out_of_bounds(oct, pos)
      if oldCenter != mycell.origin
        isInShadow_bool = intersectBool(mycell.triangles, pos, rSun_hat)
        if isInShadow_bool == true
          isInShadow[i] = true
          break
        end
        oldCenter[:] = mycell.origin
      end
      pos += mycell.halfSize .* 0.5 .* rSun_hat
      didFind, mycell = cell_containing_point(oct, pos)
    end
  end
  if i%1000 == 0
    @show(i)
  end
end
println(sum(isInShadow) / nTriangles)

mesh2vtk(meshFile, cos_sza, isInShadow)
