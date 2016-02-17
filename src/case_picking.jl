using Spice

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


function build_df(dataDir)
  df = DataFrame()
  fileNames = AbstractString[]
  AU = Float64[]
  species = AbstractString[]
  lon = Float64[]
  lat = Float64[]
  date = DateTime[]
  for name in readdir(dataDir)
    if contains(name, ".h5")
      etStr = timeFromFileName(name)
      t = DateTime(etStr[1:10], "yyyy-mm-dd")
      au = AUfromFileName(name)
      et = utc2et(etStr)
      sp = split(name, '.')[end-1]
      rSUN, lt = spkpos("SUN", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
      r, llon, llat = reclat(rSUN)
      llon = llon / pi * 180.0
      llat = llat / pi * 180.0

      push!(fileNames, name)
      push!(AU, au)
      push!(species, sp)
      push!(lon, llon)
      push!(lat, llat)
      push!(date, t)
    end
  end
  df[:file_name] = fileNames
  df[:date] = date
  df[:AU] = AU
  df[:species] = species
  df[:lon] = lon
  df[:lat] = lat

  for t in df[:date]
    df[df[:date] .== t, :lat] = mean(df[df[:date] .== t, :lat])
  end
  return df
end

function pick_dsmc_case(df, et, species, verbose=true)
  rSUN, lt = spkpos("SUN", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
  r, llon, llat = reclat(rSUN)
  llon = llon / pi * 180.0
  llat = llat / pi * 180.0

  @show(llat)
  @show(llon)

  df[:diff_lon] = abs((((df[:lon] .- llon) + 180) % 360) - 180)
  df[:diff_lat] = abs((((df[:lat] .- llat) + 180) % 360) - 180)
  sort!(df, cols=[:diff_lat, :diff_lon])

  dfNew = df[df[:species] .== species, :]
  selected_case = dfNew[1,:file_name]
  if verbose
    println(" - Case selected          : ", selected_case)
    println(" - difference in latitude : ", dfNew[1,:diff_lat])
    println(" - difference in longitude: ", dfNew[1,:diff_lon])
  end
  return selected_case
end

function select_data_file()
  if length(parseUserFile("dataFile:")) < 1
    dataDir = parseUserFile("dataDir:")
    if length(dataDir) < 1
      println("Define either dataDir: or dataFile: in '.userSettings.conf'")
      exit()
    end
    species = parseUserFile("species:")
    if length(species) < 1
      println(" -  NO SPECIES DEFINED! Set name of species in .userSettings.conf with the \
      keyword 'species:'")
      exit()
    end
    df = build_df(dataDir)
    myCase = pick_dsmc_case(df, et, species)
    myCase = joinpath(dataDir, myCase)
  else
    myCase = parseUserFile("dataFile:")
  end
  return myCase
end
