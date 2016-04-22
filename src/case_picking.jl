using Spice

type Run
  case::AbstractString
  species::AbstractString
  nVars::Int
  variables::Vector{AbstractString}
  date::Vector{DateTime}
  r_SC::Vector{Float64}
  data::Vector{Float64}
  delta_lat::Vector{Float64}
  delta_lon::Vector{Float64}
end

function run_index(runs, caseName)
  for i=1:length(runs)
    if caseName == runs[i].case
      return i
    end
  end
  return -1
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

  df[:diff_lon] = abs(mod((df[:lon] .- llon) + 180, 360) - 180)
  df[:diff_lat] = abs(mod((df[:lat] .- llat) + 180, 360) - 180)
  sort!(df, cols=[:diff_lat, :diff_lon])

  dfNew = df[df[:species] .== species, :]

  selected_case::AbstractString = dfNew[1,:file_name]
  delta_lon::Float64 = dfNew[1,:diff_lon]
  delta_lat::Float64 = dfNew[1,:diff_lat]

  if verbose
    @show(llat)
    @show(llon)
    println(" - Case selected          : ", selected_case)
    println(" - difference in latitude : ", delta_lat)
    println(" - difference in longitude: ", delta_lon)
  end
  return selected_case, delta_lat, delta_lon
end

function select_data_file(et)
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
    myCase, dlat, dlon = pick_dsmc_case(df, et, species, false)
    myCase = joinpath(dataDir, myCase)
  else
    myCase = parseUserFile("dataFile:")
  end
  return myCase
end

function select_data_file(df, et, species)
  dataDir = parseUserFile("dataDir:")
  myCase, dlat, dlon = pick_dsmc_case(df, et, species, false)
  myCase = joinpath(dataDir, myCase)
  return myCase, dlat, dlon
end
