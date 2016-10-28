path = "/home/abieler/ices/ices-desktop/work/output/"

fid = open("nrDensity_O2_ALICE_October_2015.csv", "w")
write(fid, "O2 column density in 1/m2 is tabulated at a given time as a function of R-Alice row number.\n")
write(fid, "yyyy-mm-ddTHH:MM:SS\trow_5\t\trow_6\t\trow_7\t\trow_8\t\trow_9\t\trow_10\t\trow_11\t\trow_12\t\trow_13\t\trow_14\t\trow_15\t\trow_16\t\trow_17\t\trow_18\t\trow_19\t\trow_20\t\trow_21\t\trow_22\t\trow_23\n")

for fileName in sort(readdir(path))
    if contains(fileName, "NumberDensity")
        data = readcsv(joinpath(path,fileName))
        x = collect(5:23)
        y = data[:,1]
        tStr = matchall(r"\d+-\d+-\d+T\d+:\d+:\d+", fileName)[1]

        @printf(fid, "%s\t", tStr)
        for i = 1:length(x)-1
            @printf(fid, "%.3e\t", y[i])
        end
        @printf(fid, "%.3e\n", y[end])
    end
end
close(fid)

