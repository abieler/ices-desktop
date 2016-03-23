using Triangles
using DataFrames

function save_result(ccd, mask, nVars, varNames, nPixelsX, nPixelsY, etStr)
    prevDir = pwd()
    wrkDir = parseUserFile("workingDir:")
    cd(joinpath(wrkDir, "output"))
    ccd = reshape(ccd, nVars, nPixelsX, nPixelsY)
    ccd_sum = zeros(nPixelsX, nPixelsY)
    if doBlankBody
      mask = reshape(mask, nPixelsX, nPixelsY)
      border_mask = get_border(mask)
      custom_mask!(mask)
    end
    for i=1:nVars
      ccdPlt = reshape(ccd[i,:,:], nPixelsX, nPixelsY)
      for ix = 1:nPixelsX
        for iy = 1:nPixelsY
           ccd_sum[ix, iy] += ccdPlt[ix, iy]
         end
       end
      writedlm("ccd_" * varNames[i] * "_" * etStr * ".dat", ccdPlt)
    end
    cd(prevDir)
end
function plot_result(ccd, mask, nVars, nPixesX, nPixelsY)
    # reshape ccd from a 1D array to nVar times 2D arrays.
    ccd = reshape(ccd, nVars, nPixelsX, nPixelsY)
    ccd_sum = zeros(nPixelsX, nPixelsY)
    if doBlankBody
      mask = reshape(mask, nPixelsX, nPixelsY)
      border_mask = get_border(mask)
      custom_mask!(mask)
    end

    cmap = ColorMap("hot")
    if length(parseUserFile("pltColorMap:")) > 0
      cmapUser = parseUserFile("pltColorMap:")
      try
        cmap = ColorMap(cmapUser)
      catch
        print_with_color(:red, " - your colormap was not found. using default 'hot'\n")
        println(" - some valid choices are: afmhot, autumn, bone, cool")
        println(" - copper, gist_heat, gray, pink, spring, summer, winter")
        println(" - Blues, Greens, Oranges, Reds, YlGn, BuPu, Greys, YlGnBu")
      end
    end

    nLevels = 32
    if length(parseUserFile("pltLevels:")) > 0
      nLevels = parse(Int, parseUserFile("pltLevels:"))
    end

    pltTitle = "I love Julia (by Valeriy T.)"
    if length(parseUserFile("pltTitle:")) > 0
      pltTitle = parseUserFile("pltTitle:")
    end

    fontSize = 12
    if length(parseUserFile("pltFontSize:")) > 0
      fontSize = parse(Int, parseUserFile("pltFontSize:"))
    end

    for i=1:nVars
      figure()
      ccdPlt = reshape(ccd[i,:,:], nPixelsX, nPixelsY)
      if minimum(ccdPlt) > 0.0
        contourf(log10(ccdPlt), nLevels, cmap=cmap)
      else
        contourf(ccdPlt, nLevels, cmap=cmap)
      end
      colorbar()
      if doBlankBody
        contourf(mask, levels=[-0.1, 0.1], colors=("w"))
        contourf(border_mask, levels=[0.9, 1.1], colors=("k"))
      end
      xlabel("Pixel number", size=fontSize)
      ylabel("Pixel number", size=fontSize)
      title(varNames[i], size=fontSize)
      for ix = 1:nPixelsX
        for iy = 1:nPixelsY
           ccd_sum[ix, iy] += ccdPlt[ix, iy]
         end
       end
    end
    figure()
    contourf(log10(ccd_sum), nLevels, cmap=cmap)
    xlabel("Pixel number", size=fontSize)
    ylabel("Pixel number", size=fontSize)
    title("Sum", size=fontSize)
    colorbar()
    show()
end

function custom_mask!(mask)
  mask_original = deepcopy(mask)
  ixMax, iyMax = size(mask)
  p0 = zeros(Int64, 2)
  additionalBorderWidth = 0
  try
    additionalBorderWidth = parse(Int, parseUserFile("pltAdditionalBorderPx:"))
  catch e
    println(e)
  end
  aBW = additionalBorderWidth
  for ix = 1:ixMax
    for iy =1:iyMax
      p0[1] = ix
      p0[2] = iy
      for iix = 1:ixMax
        for iiy = 1:iyMax
          distance = sqrt((ix-iix)^2 + (iy-iiy)^2)
          if distance <= aBW && mask_original[iix, iiy] == 0.0
            mask[ix, iy] = 0.0
          end
        end
      end
    end
  end
end

function check_all_neighbors(ix, iy, mask)
  inFound = false
  outFound = false
  for iix = ix-1:ix+1
    for iiy = iy-1:iy+1
      if mask[iix, iiy] == 0
        inFound = true
      else
        outFound = true
      end
    end
  end
  return (inFound && outFound)
end


function get_border(mask)
  border_mask = zeros(Int64, size(mask))
  ixMax, iyMax = size(mask)
  for ix = 2:ixMax-1
    for iy = 2:iyMax-1
      isBorder = false
      if mask[ix, iy] == 0
        isBorder = check_all_neighbors(ix, iy, mask)
      end
      if isBorder
        border_mask[ix, iy] = 1
      end
    end
  end
  return border_mask
end

function load_user_coordinates(fileName, nDims=3)

  iFile = open(fileName, "r")
  coords = Float64[]
  while !eof(iFile)
    line = readline(iFile)
    for element in split(line, ',')
      push!(coords, parse(Float64, element))
    end
  end

  nPoints = Int(length(coords)/nDims)
  coords = reshape(coords, nDims, nPoints)
  return coords
end


function parseUserFile(keyword)
 value = ""
 iFile = open("../.userSettings.conf")
 while !eof(iFile)
   line = readline(iFile)
   if contains(line, keyword)
     value = string(bytestring(split(line, keyword)[2][1:end-1]))
     return value
   end
 end
 return value
end

function load_pointing_vectors(fileName::ASCIIString)
  df = readtable(fileName, skipstart=0, separator=',', header=false)
  const nVectors = size(df)[1]
  r_hat = zeros(nVectors,3)
  r = zeros(nVectors,3)

  for i=1:nVectors
    for j=1:3
      r[i,j] = df[i,j]
      r_hat[i,j] = df[i,j+3]
    end
  end

  return r, r_hat, nVectors
end

function load_AMPS_data(fileName::UTF8String)
  f = open(fileName, "r")
  nNodes = 0
  nCells = 0
  nCellsPerBlock = 125
  nBlocks = 0
  nHeaderRows = 2

  varIndexes = [1,2,3]
  varNames = ASCIIString["x", "y", "z"]
  minSize = Float64[]
  maxSize = Float64[]
  while !eof(f)
    line = readline(f)
    if ismatch(r"VARIABLE", line)
      if ismatch(r"Dust", line)
        isDustCase = true
      else
        isDustCase = false
      end
      line_split = split(line, ',')
      if myid() == 1
        println(" - nVars in header: ", length(line_split))
      end
      i=1
      for variable in line_split
        c1 = ismatch(r"Dust Number Density", variable)
        c2 = !ismatch(r"Total", variable)
        c3 = ismatch(r"Number Density", variable)
        c4 = ismatch(r"Translational Temperature", variable)
        c5 = !ismatch(r"Dust", variable)
        c6 = ismatch(r"V[012]", variable)
        c7 = ismatch(r"Speed", variable)
        c8 = ismatch(r"Trot", variable)
        if (c1 & c2) | ((c3 | c4 | c6 | c7 | c8) & c5 & !isDustCase)
          if myid() ==1
            println(" - variable: " * variable)
          end
          push!(varIndexes, i)
          push!(varNames, replace(replace(variable, "\"", ""), " ", ""))
          if (c1 & c2) # dust case
            lower, upper = [parse(Float64, value) for value in matchall(r"(-?\d.\d+[eE][+-]\d+)", variable) ]
          else
            lower = 0.0
            upper = 0.0
          end
          push!(minSize, lower)
          push!(maxSize, upper)
        end
        i+=1
      end
    end
    if ismatch(r"ZONE ", line)
      nNodes, nCells = [parse(Int64, value) for value in matchall(r"(\d+)", line)]
      nBlocks = round(Int64, nCells / nCellsPerBlock)
      if myid() ==1
        println(" - nNodes: ", nNodes)
        println(" - nCells: ", nCells)
      end
      break
    end
  end
  close(f)
  nVars = length(minSize)
  nodeCoordinates = Array(Float64, nNodes, 3)
  numberDensity = Array(Float64, nVars, nNodes)
  cubeIndices = Array(Int64, nCells, 8)

  f = open(fileName, "r")
  i = 1
  while !eof(f)
    line = readline(f)
    if (i <= (nNodes+nHeaderRows)) && (i>nHeaderRows)
      data = [parse(Float64, value) for value in split(strip(line), r"\s+")[varIndexes]]
      nodeCoordinates[i-nHeaderRows, 1] = data[1]
      nodeCoordinates[i-nHeaderRows, 2] = data[2]
      nodeCoordinates[i-nHeaderRows, 3] = data[3]
      for kk=1:nVars
        numberDensity[kk,i-nHeaderRows] = data[kk+3]
      end
    elseif (i > (nNodes+nHeaderRows))
      ijk = [parse(Int64, value) for value in matchall(r"(\d+)", line)]
      for index in 1:8
        cubeIndices[i-nNodes-nHeaderRows, index] = ijk[index]
      end
    end
    i+=1
  end
  close(f)
  return (nCells, nCellsPerBlock, nBlocks, nodeCoordinates, cubeIndices,
         numberDensity, minSize, maxSize, varNames)
end

function load_ply_file(fileName::ASCIIString)
  if myid() == 1
    println(" - loading surface mesh...")
  end
  nNodes::Int64 = 0
  nTriangles::Int64 = 0
  iHeader::Int64 = 0
  i::Int64 = 0
  iFile = open(fileName, "r")
  while !eof(iFile)
    line = readline(iFile)
    if contains(line, "element vertex")
      nNodes = parse(Int, split(line, " ")[3])
    elseif contains(line, "element face")
      nTriangles = parse(Int, split(line, " ")[3])
    elseif contains(line, "end_header")
      iHeader = i
      break
    end
    i += 1
  end
  close(iFile)
  if myid() == 1
    println("       nNodes     : ", nNodes)
    println("       nTriangles : ", nTriangles)
    println("       iHeader    : ", iHeader)
  end

  nodeCoords = zeros(Float64, 3, nNodes)
  triIndices = zeros(Int64, 3, nTriangles)

  i = 0
  iFile = open(fileName, "r")
  while !eof(iFile)
    line = readline(iFile)
    if iHeader < i <= iHeader+nNodes
      xyz = matchall(r"-?\d+(\.\d+)?", line)
      nodeCoords[1,i-iHeader] = float(xyz[1])
      nodeCoords[2,i-iHeader] = float(xyz[2])
      nodeCoords[3,i-iHeader] = float(xyz[3])
    elseif i > iHeader+nNodes
      ijk = matchall(r"(\d+)", line)
      triIndices[1,i-iHeader-nNodes] = parse(Int, ijk[2])+1
      triIndices[2,i-iHeader-nNodes] = parse(Int, ijk[3])+1
      triIndices[3,i-iHeader-nNodes] = parse(Int, ijk[4])+1
    end
    i += 1
  end
  close(iFile)

  triangles = build_triangles(nodeCoords, triIndices, nTriangles)
  n_hat = calculate_surface_normals(nodeCoords, triIndices, nTriangles)
  triCenters = calculate_tri_centers(triangles, nTriangles)
  triAreas = calculate_tri_areas(triangles, nTriangles)
  n_hat = calculate_surface_normals(nodeCoords, triIndices, nTriangles)

  allTriangles = Array(Triangle, nTriangles)
  for i=1:nTriangles
    tri = Triangle(i, triCenters[1:3, i], triangles[1:3,1:3,i],
                   triAreas[i], n_hat[1:3,i])
    allTriangles[i] = tri
  end

  totalSurfaceArea = sum(triAreas)
  return nTriangles, allTriangles, totalSurfaceArea
end

function save2vtk(oct)
  println("saving simulation domain to disk")
  indexTransform = Dict{Int64, Int64}()
  indexTransform[1] = 1
  indexTransform[2] = 5
  indexTransform[3] = 3
  indexTransform[4] = 7
  indexTransform[5] = 2
  indexTransform[6] = 6
  indexTransform[7] = 4
  indexTransform[8] = 8

  allCells = Cell[]
  all_cells!(oct, allCells)
  nCells = length(allCells)
  println("nCells: ", nCells)
  epsilon = 1e-10
  coord = zeros(Float64,3)

  #uniqueCoords = Set{Vector{Float64}}()
  uniqueCoords = Vector{Float64}[]
  allIndexes = zeros(Int64, 8, nCells)
  allIndexesVTK = zeros(Int64, 8, nCells)
  jj = 1
  println("nCells: ", nCells)
  for cell in allCells
    for nNode=1:8
      for i=1:3
        coord[i] = cell.nodes[i,nNode]
      end
      if !in(uniqueCoords, coord)
        push!(uniqueCoords, copy(coord))
        allIndexes[nNode, jj] = length(uniqueCoords)-1
      else
        allIndexes[nNode, jj] = findfirst(x -> x == coord, uniqueCoords)-1
      end
    end
    jj+=1
  end

  nUniqueCoords = length(uniqueCoords)
  println("nUniqueCoords: ", nUniqueCoords)

  for i=1:nCells
    for k=1:8
      allIndexesVTK[k,i] = allIndexes[indexTransform[k],i]
    end
  end

  oFile = open("../output/domain.vtk", "w")
  write(oFile , "# vtk DataFile Version 3.0\n")
  write(oFile, "some mesh\n")
  write(oFile, "ASCII\n")
  write(oFile, "\n")
  write(oFile, "DATASET UNSTRUCTURED_GRID\n")
  write(oFile, "POINTS " * string(nUniqueCoords) * " float\n")
  #nodeCoords_array = zeros(Float64, 3, length(uniqueCoords))
  i=1
  for p in uniqueCoords
    write(oFile, string(p[1]), " ", string(p[2]), " ", string(p[3]), "\n")
    i+=1
  end
  write(oFile, "\n")

  write(oFile, "CELLS " * string(nCells) * " " * string(nCells*9) * "\n")
  for i=1:size(allIndexes,2)
    write(oFile, "8 ")
    for k = 1:7
      write(oFile, string(allIndexesVTK[k,i]) * " ")
    end
    write(oFile, string(allIndexesVTK[8,i]) * "\n")
  end
  write(oFile, "\n")

  write(oFile, "CELL_TYPES " *string(nCells) * "\n")
  for i=1:nCells
    write(oFile, "11\n")
  end
  write(oFile, "\n")
  write(oFile, "CELL_DATA " * string(nCells) * "\n")
  #write(oFile, "SCALARS density float\n")
  #write(oFile, "LOOKUP_TABLE default\n")
  write(oFile, "FIELD scalarField 3\n")

  write(oFile, "numberDensity 1 " * string(nCells) * " float\n")
  for i=1:nCells
    write(oFile, string(allCells[i].data[1]) * "\n")
  end
  write(oFile, "cellVolume 1 " * string(nCells) * " float\n")
  for i=1:nCells
    write(oFile, string(allCells[i].volume) * "\n")
  end

  write(oFile, "nParticlesInCell 1 " * string(nCells) * " float\n")
  for i=1:nCells
    write(oFile, string(length(allCells[i].particles)) * "\n")
  end

  close(oFile)
end


function save_particles(oct, fileName)
  println("saving particles to file")
  oFile = open(fileName, "w")
  write(oFile, "x,y,z,vx,vy,vz\n")
  data2CSV(oct, oFile)
  close(oFile)
  println("done!")
end

function data2CSV(oct, oFile)
  for child in oct.children
    if child.isLeaf
      for cell in child.cells
          for p in cell.particles
            @printf oFile "%.3e,%3.e,%.3e,%.3e,%.3e,%.3e\n" p.x p.y p.z p.vx p.vy p.vz
          end
      end
    else
      data2CSV(child, oFile)
    end
  end
end

function timeFromFileName(fileName)
  f = basename(fileName)
  dateStr = matchall(r"(\d{8})", f)[1]
  yyyy = parse(Int, dateStr[1:4])
  mm = parse(Int, dateStr[5:6])
  dd = parse(Int, dateStr[7:8])
  timeStr = matchall(r"(T\d{4})", f)[1]
  HH = parse(Int, timeStr[2:3])
  MM = parse(Int, timeStr[4:5])
  SS = 0
  etStr = string(DateTime(yyyy, mm, dd, HH, MM, SS))
  return etStr
end

function AUfromFileName(fileName)
  f = basename(fileName)
  parse(Float64, matchall(r"(\d+\.\d+)", f)[1])
end

function reshape_insitu_data(runs, sp)
    firstFound = false
    nVars = 0
    varNames = AbstractString[]
    for i in 1:length(runs)
      if (runs[i].species == sp)
        if firstFound == false
          alldata = reshape(runs[i].data, (runs[i].nVars, length(runs[i].date)))
          alldates = runs[i].date
          alldlats = runs[i].delta_lat
          alldlons = runs[i].delta_lon
          allrunnames = AbstractString[basename(runs[i].case) for k=1:length(runs[i].date)]
          nVars = runs[i].nVars
          varNames = runs[i].variables
          firstFound = true
        else
          alldata = hcat(alldata, reshape(runs[i].data, (runs[i].nVars, length(runs[i].date))))
          append!(alldlats, runs[i].delta_lat)
          append!(alldlons, runs[i].delta_lon)
          append!(alldates, runs[i].date)
          append!(allrunnames, AbstractString[basename(runs[i].case) for k=1:length(runs[i].date)])

        end
      end
    end

    sortIndex = sortperm(alldates)
    alldates = alldates[sortIndex]
    alldata = alldata[:,sortIndex]
    alldlats = alldlats[sortIndex]
    alldlons = alldlons[sortIndex]
    allrunnames = allrunnames[sortIndex]

    return alldates, alldata, alldlats, alldlons, nVars, varNames, allrunnames

end

function write_to_disk(dd, sp)
  alldates, alldata, alldlats, alldlons, nVars, varNames, allrunnames = dd
  outputDir = joinpath(parseUserFile("workingDir:"), "output")
  fileName = "result_" * sp * ".dat"
  fid = open(joinpath(outputDir, fileName), "w")
  write(fid, "date,run_name,")
  for i=1:nVars
    write(fid, varNames[i], ",")
  end
  write(fid, "delta_lat,delta_lon\n")
  for i=1:length(alldates)
    write(fid, string(alldates[i]), ",")
    write(fid, allrunnames[i], ",")
    for k=1:nVars
      write(fid, string(alldata[k,i]), ",")
    end
    write(fid, string(alldlats[i]), ",")
    write(fid, string(alldlons[i]), "\n")
  end
  close(fid)
end

function save_insitu_results(runs, species)
  for sp in species
    write_to_disk(reshape_insitu_data(runs, sp), sp)
  end
end

function save_interpolation_results(nVars, result, coords, fileName="interp_output.dat")
  fileName = joinpath(parseUserFile("workingDir:"), "output", basename(fileName))
  nPoints = size(result, 2)
  oFile = open(fileName, "w")
  for i=1:nPoints
    for k=1:3
      @printf(oFile, "%.9e ", coords[k,i])
    end
    for k=1:nVars
      @printf(oFile, "%.5e ", result[k,i])
    end
    @printf(oFile, "\n")
  end
end

function interpolate(nVars, coords, oct)
  nPoints = size(coords, 2)
  data = zeros(Float64, nVars)
  myPoint = zeros(Float64, 3)
  result = zeros(Float64, nVars, nPoints)
  norms = Float64[]
  for i=1:nPoints
    for k=1:3
      myPoint[k] = coords[k,i]
    end

    didFindCell, myCell = cell_containing_point(oct, myPoint)
    if (didFindCell == true)
      triLinearInterpolation!(myCell, myPoint, data, 0.0, 0.0, 0.0)
    end

    for j=1:nVars
      result[j,i] = data[j]
      data[j] = 0.0
    end
  end
  return result
end


function time_period(ARGS)

  secs = ["s", "sec", "second", "seconds"]
  mins = ["min", "minute", "minutes"]
  hrs = ["h", "hour", "hours"]
  days = ["d", "day", "days"]

  tt = DateTime[]

  if length(ARGS) == 3
    t = DateTime(ARGS[1])
    tStop = DateTime(ARGS[2])
    dt = Dates.Second(parse(Int,ARGS[3]))
    while t < tStop
      push!(tt, t)
      t += dt
    end
  elseif length(ARGS) == 4
    t = DateTime(ARGS[1])
    tStop = DateTime(ARGS[2])
    t_unit = lowercase(ARGS[4])
    if any(t_unit .== secs)
      dt = Dates.Second(parse(Int, ARGS[3]))
    elseif any(t_unit .== mins)
      dt = Dates.Minute(parse(Int, ARGS[3]))
    elseif any(t_unit .== hrs)
      dt = Dates.Hour(parse(Int, ARGS[3]))
    elseif any(t_unit .== days)
      dt = Dates.Day(parse(Int, ARGS[3]))
    else
      println(" -  Did not find time unit use one of the following:")
      println(secs)
      println(mins)
      println(hrs)
      println(days)
      exit()
    end
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

  return tt
end
