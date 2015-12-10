function get_object_files(path)

  objectFiles = AbstractString[]
  for fileName in readdir(path)
    if split(fileName, '.')[end] == "o"
      push!(objectFiles, fileName)
    end
  end
  return objectFiles

end

function compileLinux(tmpdir)
  previousDir = pwd()
  cd(joinpath(tmpdir, "lib"))
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

function compileOSX(tmpdir)
  previousDir = pwd()
  cd(joinpath(tmpdir, "lib"))
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

function get_tmp_dir()
  keyword = "tmpDir:"
  iFile = open(".userSettings.conf", "r")
  while !eof(iFile)
    line = readline(iFile)
    if contains(line, keyword)
      value = string(bytestring(split(line, keyword)[2][1:end-1]))
      close(iFile)
      return value
    end
  end
  println(" - tmpDir not found in .userSettings.conf.")
  println(" - run julia Config.jl --tmpdir <path to tmpdir>")
  close(iFile)
  exit()
end

function config_data_file(ARGS, case="dataFile:")
  try
    dataFile = ARGS[2]
    @show(dataFile)
    tmpdir = get_tmp_dir()
    if contains(dataFile, ".h5")
      cp(dataFile, joinpath(tmpdir, "input/"*basename(dataFile)), remove_destination=true)
      updateSettings("dataFile:", joinpath(tmpdir, "input/"*basename(dataFile)))
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

        mv(newDataFile, joinpath(tmpdir, "input/"*newBase), remove_destination=true)
        updateSettings(case, joinpath(tmpdir, "input/"*newBase))
      end
    end
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the data file, try again later")
    println(" - to set it with 'julia Config.jl --dataFile /path/to/data/file.dat'")
    println(" ------------------------------------------------------------------")
  end

end

function config_tmpdir(ARGS)
  try
    rundir = ""
    try
      rundir = ARGS[2]
    catch
      rundir = pwd()
    end

    if isdir(rundir)
      println(" - tmpdir already exists")
      if (isdir(joinpath(rundir, "lib")) | isdir(joinpath(rundir, "input")))
        print(" - directory 'lib' or 'input' already exist, remove them? (y/n): ")
        answer = readline(STDIN)
        if contains(lowercase(answer), "y")
          try
            rm(joinpath(rundir, "lib"), recursive=true)
          catch
          end
          try
            rm(joinpath(rundir, "input"), recursive=true)
          catch
          end
          mkdir(joinpath(rundir, "lib"))
          mkdir(joinpath(rundir, "input"))
        end
      else
        println(" - create new directories 'lib' and 'input'")
        mkdir(joinpath(rundir, "lib"))
        mkdir(joinpath(rundir, "input"))
      end
    else
      mkdir(rundir)
      mkdir(joinpath(rundir, "lib"))
      mkdir(joinpath(rundir, "input"))
    end
    touch(".userSettings.conf")
    updateSettings("tmpDir:", rundir)
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the tmpDir, try again later")
    println(" - to set it with 'julia Config.jl --tmpDir /path/to/dir'")
    println(" ------------------------------------------------------------------")
  end

end

function config_spicelib(ARGS)
  try
    sharedLibPath = ARGS[2]
    tmpdir = get_tmp_dir()
    cp(joinpath(sharedLibPath, "cspice.a"),
       joinpath(tmpdir, "lib/cspice.a"),
       remove_destination=true)

    cp(joinpath(sharedLibPath, "csupport.a"),
       joinpath(tmpdir, "lib/csupport.a"),
       remove_destination=true)

    if os == "linux"
      objectFiles = compileLinux(tmpdir)
      updateSettings("spicelib:", joinpath(tmpdir, "lib/spice.so"))
    else
      objectFiles = compileOSX(tmpdir)
      updateSettings("spicelib:", joinpath(tmpdir, "lib/spice.dylib"))
    end
    previousDir = pwd()
    cd(joinpath(tmpdir, "lib"))
    run(`rm $objectFiles`)
    cd(previousDir)
  catch
    println(" ------------------------------------------------------------------")
    println(" - There was an error with setting up the spicelib, try again later")
    println(" - to set it with 'julia Config.jl --spicelib /path/to/spicelib'")
    println(" ------------------------------------------------------------------")
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
  tmpdir = get_tmp_dir()
  if os == "linux"
    ext = ".so"
  else
    ext = ".dylib"
  end

  try
    cp(clibFile, joinpath(tmpdir, "lib/"*basename(clibFile)), remove_destination=true)
    sharedLibName = joinpath(tmpdir, "lib/clib" * ext )
    updateSettings("clibFile:", sharedLibName)
    if os == "linux"
      compileClibLinux(joinpath(tmpdir, "lib/"*basename(clibFile)))
    else
      compileClibOSX(joinpath(tmpdir, "lib/"*basename(clibFile)))
    end
  catch
    println("Did not find c library! ")
    updateSettings("clibFile:", "")
  end
end

function config_meshfile(ARGS)
  try
    meshFile = ARGS[2]
    tmpdir = get_tmp_dir()
    cp(meshFile, joinpath(tmpdir, "input/"*basename(meshFile)), remove_destination=true)
    updateSettings("meshFile:", joinpath(tmpdir, "input/"*basename(meshFile)))
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
    tmpdir = get_tmp_dir()
    cp(meshFile, joinpath(tmpdir, "input/"*basename(meshFile)), remove_destination=true)
    cp(meshFile, joinpath(tmpdir, "input/"*basename(meshFile)), remove_destination=true)
    updateSettings("meshFileShadow:", joinpath(tmpdir, "input/"*basename(meshFile)))
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

if lowercase(ARGS[1]) == "--tmpdir"
  config_tmpdir(ARGS)

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
  tmpdir = get_tmp_dir()
  previousDir = pwd()
  cd(joinpath(tmpdir, "lib"))
  allFiles = readdir()
  if length(allFiles) > 0
    run(`rm $allFiles`)
  end
  cd(joinpath(tmpdir, "input"))
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
    println(" - option arguments are case insensitive (tmpDir == TmpDIR)")
    println("")
    println("--tmpdir          directory where files for runs are stored")
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
    println("--tmpdir          directory where files for runs are stored")
    println("--spicelib        directory to cspice.a and csupport.a")
    println("--kernelfile      spice kernel metafile")
    println("--meshfile        .ply file of the body surface mesh")
    println("--datafile        Full path to .h5 or .dat AMPS output file")
    println("--clib            custom shared library to be used in LOS calculation")
    println("--meshfileshadow  .ply file of the body surface mesh for shadow calc.")
    println("--docheckshadow   yes or no if shadow calculation is needed")
    println("")
    println("")
  print("--tmpdir ")
  arg = parseCmdLineArg()
  config_tmpdir(["", arg])
  println("OK")

  print("--spicelib ")
  arg = parseCmdLineArg()
  config_spicelib(["", arg])
  println("OK")

  print("--kernelfile ")
  arg = parseCmdLineArg()
  config_kernelfile(["", arg])
  println("OK")

  print("--meshfile ")
  arg = parseCmdLineArg()
  config_meshfile(["", arg])
  println("OK")

  print("--datafile ")
  arg = parseCmdLineArg()
  config_data_file(["", arg])
  println("OK")

  println()
  println(" - Mandatory settings done, continue with optional settings? ")
  println("   skip a parameter by hitting enter without giving an input.")
  print(  "   continue? (y/n) ")
  answ = readline(STDIN)
  if !contains(answ, "n")
    println()
    print("--clib ")
    arg = parseCmdLineArg()
    if length(arg) < 1
      println(" - ...skipped")
    else
      config_clib(["", arg])
      println("OK")
    end

    print("--meshFileShadow ")
    arg = parseCmdLineArg()
    if length(arg) < 1
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
