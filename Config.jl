using Spice
using Requests
import Requests: get

function get_spice(path)
root_url = "http://naif.jpl.nasa.gov/pub/naif/toolkit/C/"

@linux_only platform_url = "PC_Linux_GCC_64bit/"
@osx_only platform_url = "MacIntel_OSX_AppleC_64bit/"
@windows_only println("Windows not supported")

pkg_name = "packages/cspice.tar.Z"

full_url = root_url * platform_url * pkg_name
println()
println(" - Downloading SPICE library:")
println("   ", full_url)
print("   This might take a moment...   ")
cspice_archive = get(full_url)
println("OK")
save(cspice_archive, joinpath(path, "cspice.tar.Z"))
end

function get_spice_kernels()
  url = "https://www.dropbox.com/s/7qr8e1kmeij2e71/spiceKernels.zip?dl=1"
  println()
  println(" - Downloading SPICE kernels:")
  println("   ", url)
  print("   This might take a moment...   ")
  kernels = get(url)
  save(kernels, "spiceKernels.zip")
  println("OK")
end

function get_additional_data()
  url = "https://www.dropbox.com/s/rp23i57dgwjpkob/additionalData.zip?dl=1"
  println()
  println(" - Downloading additional data:")
  println("   ", url)
  print("   This might take a moment...   ")
  data = get(url)
  save(data, "additionalData.zip")
  println("OK")
end


function get_object_files(path)

  objectFiles = AbstractString[]
  for fileName in readdir(path)
    if split(fileName, '.')[end] == "o"
      push!(objectFiles, fileName)
    end
  end
  return objectFiles

end

function compileLinux(datadir)
  previousDir = pwd()
  cd(joinpath(datadir, "lib"))
  run(`ar -x cspice.a`)
  run(`ar -x csupport.a`)
  objectFiles = get_object_files(".")
  run(`gcc -shared -fPIC -lm $objectFiles -o spice.so`)
  cd(previousDir)
  return objectFiles
end

function compileClibLinux(fileName)
  previousDir = pwd()
  cd(dirname(fileName))
  cFile = basename(fileName)
  run(`gcc -shared -c -fPIC $cFile`)
  println(`gcc -shared -c -fPIC $cFile`)
  objectFiles = get_object_files(".")
  run(`gcc -shared -fPIC -lm $objectFiles -o clib.so`)
  println(`gcc -shared -fPIC -lm $objectFiles -o clib.so`)
  run(`rm $objectFiles`)
  println(`rm $objectFiles`)
  cd(previousDir)
end

function compileOSX(datadir)
  previousDir = pwd()
  cd(joinpath(datadir, "lib"))
  run(`ar -x cspice.a`)
  run(`ar -x csupport.a`)
  objectFiles = get_object_files(".")
  run(`gcc -dynamiclib -lm $objectFiles -o spice.dylib`)
  cd(previousDir)
  return objectFiles
end

function compileClibOSX(fileName)
  previousDir = pwd()
  cd(dirname(fileName))
  cFile = basename(fileName)
  run(`gcc -c -fPIC $cFile`)
  println(`gcc -c -fPIC $cFile`)
  objectFiles = get_object_files(".")
  run(`gcc -dynamiclib -lm $objectFiles -o clib.dylib`)
  println(`gcc -dynamiclib -lm $objectFiles -o clib.dylib`)
  run(`rm $objectFiles`)
  println(`rm $objectFiles`)
  cd(previousDir)
end

function linux()
  global os
  os =  "linux"
end

function osx()
  global os
  os = "osx"
end


function updateSettings(keyword, newValue)
  mv(".userSettings.conf", ".userSettings.bkp")
  iFile = open(".userSettings.bkp", "r")
  oFile = open(".userSettings.conf", "w")
  foundKeyword = false
  while !eof(iFile)
    line = readline(iFile)
    if contains(line, keyword)
      if length(newValue) >= 1
        write(oFile, keyword, newValue, "\n")
      end
      foundKeyword = true
    else
      write(oFile, line)
    end
  end

  if (!foundKeyword) & (length(newValue) > 0)
    write(oFile, keyword, newValue, "\n")
  end

  close(iFile)
  close(oFile)
  rm(".userSettings.bkp")
end

function get_data_dir()
  keyword = "dataDir:"
  iFile = open(".userSettings.conf", "r")
  while !eof(iFile)
    line = readline(iFile)
    if contains(line, keyword)
      value = string(bytestring(split(line, keyword)[2][1:end-1]))
      close(iFile)
      return value
    end
  end
  println(" - dataDir not found in .userSettings.conf.")
  println(" - run julia Config.jl --datadir <path to datadir>")
  close(iFile)
  exit()
end

function config_data_file(ARGS, case="dataFile:")
  try
    dataFile = ARGS[2]
    datadir = get_data_dir()
    if contains(dataFile, ".h5")
      cp(dataFile, joinpath(datadir, "input/"*basename(dataFile)), remove_destination=true)
      updateSettings("dataFile:", joinpath(datadir, "input/"*basename(dataFile)))
    else
      print(" - selected data file is not in HDF5 format. Build new .h5 file? (y/n) ")
      answ = parseCmdLineArg()
      if !contains(answ, "n")
        println(" -  generating new file, this might take a few seconds.")
        cd("src")
        try
          run(`julia prepareAmpsData.jl $dataFile`)
        catch
          println(" - !!!Coulnd not convert File!!!")
        end
        cd("..")
        path = dirname(dataFile)
        baseName = basename(dataFile)
        ext = split(baseName, ".")[end]
        newBase = baseName[1:end-(length(ext)+1)] * ".h5"
        newDataFile = joinpath(path, newBase)

        mv(newDataFile, joinpath(datadir, "input/"*newBase), remove_destination=true)
        updateSettings(case, joinpath(datadir, "input/"*newBase))
      end
    end
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the data file, try again later")
    println(" - to set it with 'julia Config.jl --dataFile /path/to/data/file.dat'")
    println(" ------------------------------------------------------------------")
  end

end

function config_datadir(ARGS)
  try
    rundir = ""
    try
      rundir = ARGS[2]
    catch
      rundir = pwd()
    end

    if isdir(rundir)
      println(" - datadir already exists")
      if (isdir(joinpath(rundir, "lib")) | isdir(joinpath(rundir, "input")))
        print(" - directory 'lib', 'input' or 'output' already exist, replace them? (y/n): ")
        answer = readline(STDIN)
        if contains(lowercase(answer), "y")
          for dirname in ["lib", "input", "output"]
            try
              rm(joinpath(rundir, dirname), recursive=true)
            catch
            end
          end
          mkdir(joinpath(rundir, "lib"))
          mkdir(joinpath(rundir, "input"))
          mkdir(joinpath(rundir, "output"))
        end
      else
        println(" - create new directories 'lib', 'input' and 'output'")
        mkdir(joinpath(rundir, "lib"))
        mkdir(joinpath(rundir, "input"))
        mkdir(joinpath(rundir, "output"))
      end
    else
      mkdir(rundir)
      mkdir(joinpath(rundir, "lib"))
      mkdir(joinpath(rundir, "input"))
      mkdir(joinpath(rundir, "output"))
    end
    touch(".userSettings.conf")
    updateSettings("dataDir:", rundir)
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the dataDir, try again later")
    println(" - to set it with 'julia Config.jl --dataDir /path/to/dir'")
    println(" ------------------------------------------------------------------")
  end

end

function config_spicelib(ARGS, isLib=false)
  if !isLib
    try
      sharedLibPath = ARGS[2]
      datadir = get_data_dir()
      cp(joinpath(sharedLibPath, "cspice.a"),
         joinpath(datadir, "lib/cspice.a"),
         remove_destination=true)

      cp(joinpath(sharedLibPath, "csupport.a"),
         joinpath(datadir, "lib/csupport.a"),
         remove_destination=true)

      if os == "linux"
        objectFiles = compileLinux(datadir)
        updateSettings("spicelib:", joinpath(datadir, "lib/spice.so"))
      else
        objectFiles = compileOSX(datadir)
        updateSettings("spicelib:", joinpath(datadir, "lib/spice.dylib"))
      end
      previousDir = pwd()
      cd(joinpath(datadir, "lib"))
      run(`rm $objectFiles`)
      cd(previousDir)
    catch
      println(" ------------------------------------------------------------------")
      println(" - There was an error with setting up the spicelib, try again later")
      println(" - to set it with 'julia Config.jl --spicelib /path/to/spicelib'")
      println(" ------------------------------------------------------------------")
    end
  else
    sharedLib = ARGS[2]
    updateSettings("spicelib:", sharedLib)
  end
end

function config_kernelfile(ARGS)
  try
    kernelFile = ARGS[2]
    updateSettings("kernelFile:", kernelFile)
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the kernelFile, try again later")
    println(" - to set it with 'julia Config.jl --spicelib /path/to/metafile.tm'")
    println(" ------------------------------------------------------------------")
  end

end

function config_clib(ARGS)
  clibFile = ARGS[2]
  datadir = get_data_dir()
  if os == "linux"
    ext = ".so"
  else
    ext = ".dylib"
  end

  try
    cp(clibFile, joinpath(datadir, "lib/"*basename(clibFile)), remove_destination=true)
    sharedLibName = joinpath(datadir, "lib/clib" * ext )
    updateSettings("clibFile:", sharedLibName)
    if os == "linux"
      compileClibLinux(joinpath(datadir, "lib/"*basename(clibFile)))
    else
      compileClibOSX(joinpath(datadir, "lib/"*basename(clibFile)))
    end
  catch
    println("Did not find c library! ")
    updateSettings("clibFile:", "")
  end
end

function config_meshfile(ARGS)
  try
    meshFile = ARGS[2]
    datadir = get_data_dir()
    cp(meshFile, joinpath(datadir, "input/"*basename(meshFile)), remove_destination=true)
    updateSettings("meshFile:", joinpath(datadir, "input/"*basename(meshFile)))
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the meshfile, try again later")
    println(" - to set it with 'julia Config.jl --meshfile /path/to/meshfile.ply'")
    println(" ------------------------------------------------------------------")
  end
end

function config_meshfileshadow(ARGS)
  try
    meshFile = ARGS[2]
    datadir = get_data_dir()
    cp(meshFile, joinpath(datadir, "input/"*basename(meshFile)), remove_destination=true)
    cp(meshFile, joinpath(datadir, "input/"*basename(meshFile)), remove_destination=true)
    updateSettings("meshFileShadow:", joinpath(datadir, "input/"*basename(meshFile)))
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the meshfileshadow, try again later")
    println(" - to set it with 'julia Config.jl --meshfileshadow /path/to/meshfile.ply'")
    println(" ------------------------------------------------------------------")
  end
end

function config_docheckshadow(ARGS)
  doCheckShadow = ARGS[2]
  updateSettings("doCheckShadow:", doCheckShadow)
end

function parseCmdLineArg()
  arg = strip(string(bytestring(readline(STDIN)[1:end-1])))
end
################################################################################
# start main
################################################################################

os = "operatingSystem"
@linux?  linux() : osx()

if lowercase(ARGS[1]) == "--datadir"
  config_datadir(ARGS)

elseif lowercase(ARGS[1]) == "--spicelib"
  config_spicelib(ARGS)

elseif lowercase(ARGS[1]) == "--kernelfile"
  config_kernelfile(ARGS)

elseif lowercase(ARGS[1]) == "--clib"
  config_clib(ARGS)

elseif lowercase(ARGS[1]) == "--noclib"
  updateSettings("clibFile:", "")

elseif lowercase(ARGS[1]) == "--meshfile"
  config_meshfile(ARGS)

elseif lowercase(ARGS[1]) == "--meshfileshadow"
  config_meshfileshadow(ARGS)

elseif lowercase(ARGS[1]) == "--docheckshadow"
  config_docheckshadow(ARGS)

elseif lowercase(ARGS[1]) == "--datafile"
  config_data_file(ARGS)

elseif lowercase(ARGS[1]) == "--datafiletestgas"
  config_data_file(ARGS, "dataFileTestGas:")

elseif lowercase(ARGS[1]) == "--datafiletestdust"
  config_data_file(ARGS, "dataFileTestDust:")

elseif lowercase(ARGS[1]) == "--clean"
  datadir = get_data_dir()
  previousDir = pwd()
  cd(joinpath(datadir, "lib"))
  allFiles = readdir()
  if length(allFiles) > 0
    run(`rm $allFiles`)
  end
  cd(joinpath(datadir, "input"))
  allFiles = readdir()
  if length(allFiles) > 0
    run(`rm $allFiles`)
  end
  cd(previousDir)

elseif lowercase(ARGS[1]) == "--show"
  iFile = open(".userSettings.conf", "r")
  while !eof(iFile)
    print(" \u2764 " * readline(iFile))
  end
  close(iFile)
elseif lowercase(ARGS[1]) == "--help"
  print(" \U2665 say please: ")
  answ = readline(STDIN)
  if contains(lowercase(answ), "please")
    println(" - Thanks! You have the following options to call Config.jl:")
    println(" - All paths have to be absolute.")
    println(" - option arguments are case insensitive (datadir == datadir)")
    println("")
    println("--datadir          directory where files for runs are stored")
    println("--spicelib        directory to cspice.a and csupport.a")
    println("--kernelfile      spice kernel metafile")
    println("--clib            custom shared library to be used in LOS calculation")
    println("--noclib          do not use any shared c library")
    println("--meshfile        .ply file of the body surface mesh")
    println("--meshfileshadow  .ply file of the body surface mesh for shadow calc.")
    println("--docheckshadow   yes or no if shadow calculation is needed")
    println("--datafile        Full path to .h5 or .dat AMPS output file")
    println("--clean           remove 'lib' and 'input' dirs in tmpfile")
    println("--help            show this message")

  else
    println(" \U0001f631 Too bad, better luck next time...")
  end
elseif lowercase(ARGS[1]) == "--auto"
  println(" - START auto setup:")
  println(" - This will setup the necessary parameters for the ices-desktop")
  println(" - tool. settings are stored in ices-desktop/.userSettings.conf")
  println(" - You have the following options to set:")
  println(" - (All paths have to be absolute.)")
  println("")
  println(" - --datadir         directory where files for runs are stored")
  println(" - --spicelib        directory to cspice.a and csupport.a")
  println(" - --kernelfile      spice kernel metafile")
  println(" - --meshfile        .ply file of the body surface mesh")
  println(" - --datafile        Full path to .h5 or .dat AMPS output file")
  println(" - --clib            custom shared library to be used in LOS calculation")
  println(" - --meshfileshadow  .ply file of the body surface mesh for shadow calc.")
  println(" - --docheckshadow   yes or no if shadow calculation is needed")
  println("")
  println("")
  currentDir = pwd()

  defaultDir = joinpath(currentDir, "data")
  print(" - --datadir ", defaultDir, "   ")
  config_datadir(["", defaultDir])
  println("OK")

  # spice installation
  #=
  defaultDir = joinpath(pwd(), "cspice/lib/")
  if !isdir(defaultDir)
    get_spice(currentDir)
    run(`tar -zxf cspice.tar.Z`)
    rm("cspice.tar.Z")
  end
  =#
  print("   --spicelib   ", sharedLib, "   ")
  println("OK")
  isLib = true
  config_spicelib(["", sharedLib], isLib)

  # installation of spice kernels
  if !isdir("spiceKernels")
    get_spice_kernels()
    run(`unzip -qq spiceKernels.zip`)
  end

  if isfile(joinpath(pwd(), "spiceKernels/metafiles/operationalKernels.tm"))
    defaultFile = joinpath(pwd(), "spiceKernels/metafiles/operationalKernels.tm")
    print("   --kernelfile ", defaultFile, "   ")
    config_kernelfile(["", defaultFile])
    println("OK")
    rm("spiceKernels.zip")
  else
    println(" - Default SPICE kernels not found: ", defaultFile )
    println(" - Please set it up later with 'Julia Config.jl --kernelfile <path to kernelfile>'")
  end

  get_additional_data()
  run(`unzip -qq additionalData.zip`)
  for fileName in readdir(joinpath(currentDir, "additionalData"))
    cp(joinpath(currentDir, "additionalData", fileName), joinpath(currentDir, "data", fileName),
      remove_destination=true)
  end
  rm("additionalData.zip")
  run(`rm -r additionalData`)

  meshfile = joinpath(currentDir, "data", "SHAP5.ply")
  config_meshfile(["", meshfile])

  datafile = joinpath(currentDir, "data", "SHAP5-2.2-20150304T1200.H2O.dat")
  config_data_file(["", datafile])

  println()
  println(" - You can check/modify your settings in the .userSettings.conf file.")
  println()
  println(" - Mandatory settings done, continue with optional settings? ")
  println("   skip a parameter by hitting enter without giving an input.")
  print(  "   continue? (y/n) ")
  answ = readline(STDIN)
  if !contains(answ, "n")
    println()
    print(" - --clib ")
    arg = parseCmdLineArg()
    if length(arg) < 1
      println()
      println(" - ...skipped")
    else
      config_clib(["", arg])
      println("OK")
    end

    print(" - --meshFileShadow   ")
    arg = parseCmdLineArg()
    if length(arg) < 1
      println()
      println(" - ...skipped")
    else
      config_meshfileshadow(["", arg])
      println("OK")
    end

    print("--doCheckShadow ")
    arg = parseCmdLineArg()
    if length(arg) < 1
      println(" - ...skipped")
    else
      config_docheckshadow(["", arg])
      println("OK")
    end
  end


end
