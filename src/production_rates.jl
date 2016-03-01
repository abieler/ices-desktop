using Spice
include("io.jl")
include("case_picking.jl")
include("octree.jl")


if length(ARGS) == 1
  p = ARGS[1]
  run(`julia insitu.jl $p`)
elseif length(ARGS) == 3
  p1 = ARGS[1]
  p2 = ARGS[2]
  p3 = ARGS[3]
  run(`julia insitu.jl $p1 $p2 $p3`)
elseif length(ARGS) == 4
  p1 = ARGS[1]
  p2 = ARGS[2]
  p3 = ARGS[3]
  p4 = ARGS[4]
  run(`julia insitu.jl $p1 $p2 $p3 $p4`)
else
  println(" - Provide either 1, 3 or 4 command line parameters.")
end

species_str = parseUserFile("species:")
species = [s for s in split(species_str, ',')]
