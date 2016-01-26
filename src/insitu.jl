using SQLite
using Spice

include("io.jl")

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



tStart = ARGS[1]
tStop = ARGS[2]
dt = ARGS[3]

metaFile = parseUserFile("kernelFile:")
pathToData = parseUserFile("dsmcCase:")

db = SQLite.DB("../input/myDB.sqlite")
myQuery = "CREATE TABLE dsmc_case(file_name TEXT,
                                  AU INT,
                                  species TEXT,
                                  lon FLOAT,
                                  lat FLOAT)"
query(db, myQuery)
for fileName in readdir(pathToData)
  if contains(fileName, ".h5")
    etStr = timeFromFileName(fileName)
    AU = AUfromFileName(fileName)
    et = utc2et(etStr)
    rSUN, lt = spkpos("SUN", et, "67P/C-G_CK", "NONE", "CHURYUMOV-GERASIMENKO")
