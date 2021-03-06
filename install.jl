Pkg.add("Requests")
Pkg.add("DataFrames")
Pkg.add("HDF5")
Pkg.add("JLD")
Pkg.add("PyPlot")
try
  Pkg.clone("https://github.com/abieler/Spice.jl.git")
catch
end

Pkg.update()

using Spice

currentDir = pwd()
init_spice()


if !isfile(joinpath(homedir(), ".juliarc.jl"))
  fid = open(joinpath(homedir(), ".juliarc.jl"), "w")
  write(fid, "push!(LOAD_PATH, pwd())\n")
  close(fid)
else
  load_path = false
  fid = open(joinpath(homedir(), ".juliarc.jl"), "r")
  while !eof(fid)
    line = readline(fid)
    if contains(line, "LOAD_PATH, pwd())")
      load_path = true
    end
  end
  close(fid)

  if load_path == false
    fid = open(joinpath(homedir(), ".juliarc.jl"), "a")
    write(fid, "push!(LOAD_PATH, pwd())\n")
    close(fid)
  end
end


cd(currentDir)
run(`julia Config.jl --auto`)
