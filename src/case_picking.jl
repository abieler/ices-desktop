using SQLite
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
  int(matchall(r"(\d+\.\d+)", f)[1])
end


function build_sql_db(dataDir)
  try
    rm("../input/myDB.sqlite")
  catch
  end
  db = SQLite.DB("../input/myDB.sqlite")
  myQuery = "CREATE TABLE dsmc_case(file_name TEXT,
                                    AU INT,
                                    species TEXT,
                                    lon FLOAT,
                                    lat FLOAT)"
  query(db, myQuery)
  for fileName in readdir(dataDir)
    if contains(fileName, ".h5")
      etStr = timeFromFileName(fileName)
      AU = AUfromFileName(fileName)
      et = utc2et(etStr)
      species = split(fileName, '.')[end-1]
      rSUN, lt = spkpos("SUN", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
      r, llon, llat = reclat(rSUN)
      llon = llon / pi * 180.0
      llat = llat / pi * 180.0
      myQuery = "INSERT INTO dsmc_case VALUES('$fileName', $AU, '$species', $llon, $llat)"
      query(db, myQuery)
    end
  end
end

function pick_dsmc_case(db, et, species)
  rSUN, lt = spkpos("SUN", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
  r, llon, llat = reclat(rSUN)
  llon = llon / pi * 180.0
  llat = llat / pi * 180.0

  myQuery = "SELECT file_name FROM dsmc_case WHERE species = $species ORDER BY abs( (((lat-($llat)) + 180) %% 360) - 180), abs( (((lon-($llon)) + 180) %% 360) - 180) LIMIT 1;"
  sql_data = query(db, myQuery)
  @show(sql_data)
end
