#!/opt/local/anaconda/bin/python
from __future__ import division
import os
import sys
import datetime
import time
import numpy as np
import pandas as pd
import sqlite3
import matplotlib.pyplot as plt
import matplotlib

import spice
import utils.spice_functions as spice_functions


dfH2O = pd.read_csv("/home/abieler/rosetta/data/dfms/evaluated/H2O.csv")
dfCO2 = pd.read_csv("/home/abieler/rosetta/data/dfms/evaluated/CO2.csv")

df = pd.read_csv("/home/abieler/rosetta/data/dfms/evaluated/H2O.csv")
dates = [datetime.datetime.strptime(tStr, "%Y-%m-%dT%H:%M:%S") for tStr in df.date.values]
iDim = 3
frame = '67P/C-G_CK'
StringKernelMetaFile = "/home/abieler/rosetta/spiceKernels/metafiles/operationalKernels.tm"
dsmc_case = 'CG_3.5_au_83'
outputDir = "/home/abieler/ices/KCmodel/output"
pathToData = "/home/abieler/ices/KCmodel/input/CG_3.5_au_83"

print 'Rosetta coordinates in reference frame:', frame
x_SC, y_SC, z_SC, r_SC, dates_SC = spice_functions.get_coordinates(dates, StringKernelMetaFile,
                                                             'ROSETTA', frame, "None", "CHURYUMOV-GERASIMENKO")
x_sun, y_sun, z_sun, r_sun, dates_sun = spice_functions.get_coordinates(dates, StringKernelMetaFile,
                                                             'SUN', frame, "None", "CHURYUMOV-GERASIMENKO")

#####################################################
# select calculate lon/lat of Sun for each instance
# in time and check database for the best suited DSCMC case
#####################################################
db = sqlite3.connect('../ICES.sqlite')
cur = db.cursor()
tup = (dsmc_case,)

# runs is a dictionary with run names as keys,
# holding at least 3 lists. these lists have
# dates, coordinates and number densities that belong
# to this run. if more than 1 species, more number
# density lists are appended
runs = {}
runNames = []

# retrieve all possible run names for the selected case
# that means all dsmc files for all AUs
cur.execute("SELECT data_prefix FROM select3D WHERE dsmc_case=?", tup)
queryData = cur.fetchall()
for qd in queryData:
    runs[qd[0]] =  [[],[]]
    runNames.append(qd[0])

# get all longitudes and latitudes of the sun for all
# dates where data has to be interpolated
km2AU = 1.0 / 149597871
lat_sun = []
lon_sun = []
r_AU = []
shapeModel = 'rmoc'
for xx,yy,zz in zip(x_sun, y_sun, z_sun):
    r, llon, llat = spice.reclat([xx,yy,zz])
    r = r*km2AU
    llon = llon / np.pi * 180
    llat = llat / np.pi * 180
    lat_sun.append(llat)
    lon_sun.append(llon)
    r_AU.append(r)

print "selecting cases from lat lon of sun"
kk = 0
for llat, llon in zip(lat_sun, lon_sun):
    sql = "SELECT data_prefix FROM select3D WHERE dsmc_case='%s' ORDER BY abs( (((latitude-(%.3f)) + 180) %% 360) - 180), abs( (((longitude-(%.3f)) + 180) %% 360) - 180) LIMIT 1;" % (dsmc_case,llat, llon)
    cur.execute(sql)
    runName = cur.fetchone()[0]
    runs[runName][0].append(dates_SC[kk])
    if True:
      runs[runName][1].append([x_SC[kk], y_SC[kk], z_SC[kk]])
    else:
        rrr = np.sqrt(x_sun[kk]**2 + y_sun[kk]**2 + z_sun[kk]**2)
        sss = 10 * 1000
        runs[runName][1].append([x_sun[kk] / rrr * sss, y_sun[kk] /rrr * sss, z_sun[kk] / rrr * sss])

    kk += 1

species3D = []
cur.execute("SELECT species from dsmc_species WHERE dcase='%s'"% dsmc_case)
qData = cur.fetchall()
for qd in qData:
    species3D.append(qd[0])

db.close()

# build path where all fitting DSMC cases are located below


# write coordinates of each case to file and then start julia
# to perform the 3D interpolation
for key in runNames:
    if len(runs[key][0]) > 0:
        with open(outputDir + "/rosettaCoords.txt", 'w') as oFile:
            for rrr in runs[key][1]:
                oFile.write("%.5e,%.5e,%.5e\n" %(rrr[0], rrr[1], rrr[2]))
        for spec in species3D:
            runName = key+"." + spec + ".dat"
            dsmcFileName = os.path.join(pathToData, runName)
            os.system("julia in-situ.jl %s %s" %(dsmcFileName, outputDir))
            n_SC = np.genfromtxt(outputDir + '/interpolation.out', dtype=float)

            # genfromtxt returns float instead of one element array in case
            # there is only one entry --> make array out of that
            if type(n_SC) == float:
                n_SC = np.array([n_SC])
            runs[key].append(n_SC)
    else:
        pass

# combine all cases into one array and sort them according to date
numberDensities_SC = []
for i in range(len(species3D)):
    n_SC = []
    dates_SC = []
    r_SC = []
    for key in runNames:
        if len(runs[key][0]) >= 1:
            n_SC.extend(runs[key][2+i])
            dates_SC.extend(runs[key][0])
            r = [np.sqrt(p[0]**2+p[1]**2+p[2]**2) for p in runs[key][1]]
            r_SC.extend(r)
    n_SC = np.array(n_SC)
    dates_SC = np.array(dates_SC)
    r_SC = np.array(r_SC)
    sort_index = np.argsort(dates_SC)

    dates_SC = dates_SC[sort_index]
    n_SC = n_SC[sort_index]
    r_SC = r_SC[sort_index]
    numberDensities_SC.append(n_SC)
############################################
# write results to file
############################################
species = ["CO2", "H2O"]

#file = open(args.StringOutputDir + '/' + 'in_situ' + '.out', 'w')
with open(outputDir + '/' + 'in_situ.out', 'w') as file:

    file.write('date,x[m],y[m],z[m],distance_from_center[m],')
    for s in species:
        if s == species[-1]:
            file.write('%s [#/m3]' %s)
        else:
            file.write('%s [#/m3],' %s)
    file.write('\n')

    i = 0
    for dd, xx, yy, zz, rr, in zip(dates_SC, x_SC, y_SC, z_SC, r_SC):
        file.write("%s,%e,%e,%e,%e," % (dd, xx, yy, zz, rr))
        for n_SC in numberDensities_SC:
            if (np.sum(n_SC == numberDensities_SC[-1]) == len(n_SC)):
                file.write("%e" % n_SC[i])
            else:
                file.write("%e," % n_SC[i])
        file.write("\n")
        i += 1
    file.close()
print 'done'
