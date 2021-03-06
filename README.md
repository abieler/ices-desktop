INSTALLATION
============
Disclaimer: Only 64 bit machines with Linux or OSX are supported.

Julia
------

  1. install julia version >= 0.4 from your OS's package manager or else you can find binaries under the link below:
  
     http://julialang.org/downloads/


  2. a)

     **OSX users**: create the following symlink in order
     to be able to launch julia properly from the command line
     
    ```
    sudo ln -s /Applications/Julia-x.x.x.app/Contents/Resources/julia/bin/julia /usr/bin/julia
    ```

     where x.x.x is your version of the Julia install.
     
     For "El Capitan" users that does not work anymore as not even root is allowed to write to /usr/bin/. In that case          either create an alias to start the julia executable or add
     ```
     /Applications/Julia-x.x.x.app/Contents/Resources/julia/bin/
     ```
     to PATH. Again replace x.x.x with your version of Julia.

     **Linux users**: If you installed via package manager or similar, no further steps are required.
     Otherwise modify your PATH variable accordingly.
     

     b)
     open a new terminal or source your current session, then
     start julia from command line by typing:

     julia

     You should now be in the julia REPL (Read-Eval-Print-Loop) environment. The julia logo should be visible
     and some information on the version and build of your copy of julia.
     You can exit the Julia REPL by typing exit(), quit() or pressing CTRL+D
  


Git
----
  Git is not necessary to install (but recommended), you can simply download the ices-desktop tool from this page.
  However, if you install git you will be able to update the tool to the newest version via git
  through the command line using `git pull`, which downloads the latest version of the tool. If you
  install git and are a first time user, provide the following information by command line:

  ```
   git config --global user.name "John Doe"
   
   git config --global user.email johndoe@example.com
  ```

Ices-Desktop
------------
  1. Either download the ices-desktop tool by clicking the "Download ZIP" button on this page, or
     install it via git.
    
     If you choose the "Download ZIP" way, extract the archive on your hard drive and rename the
     extracted directory to "ices-desktop". You can put this folder wherever you want in your file system.
    
     For installation by git; cd into the directory you want the tool to be installed and execute
     the following command:
    
     ```
     git clone https://github.com/abieler/ices-desktop.git
     ```
    
     this downloads all necessary files from the web into a folder "ices-desktop". You can move this directory
     around your file system wherever you want. For updates later on cd into the ices-desktop folder and execute:
    
     ```
     git pull
     ```
  
  2. Inside the ices-desktop directory there is the `install.jl` script. Executing this script will
     install all missing julia packages. (Extensions to the julia base functionality)
     Run the script by typing:

     ```
     julia install.jl
     ```
    
     This step is only necessary once. After that, all those packages will remain available. However, these
     packages are being updated every now and then. To make sure you run on a current version you can start
     the julia REPL and type:
    
     ```
     Pkg.update()
     ```
    
     every few weeks. This will download and install the newest available versions.
     
     After this script is finished you are good to go.

--------------------------------------------------------------------------------
RUNNING
=======
There are three different scripts that can be run. Please read the section `CONFIGURATION` before try running
any of those scripts for the first time.


###LOS.jl
This performs line of sight integration at user defined times. Rosetta instruments are already pre definded
with the correct number of pixels and field of views. Additionally you can define your own 'instrument' in
the Instrument.jl file. You simply have to define the number of pixels in x and y direction and the corresponding
filed of view angles.

Run the LOS.jl script from within the src directory with two arguments, 'date' and 'Instrument':
```
julia LOS.jl date instrument
```

Where `date` is the UTC datetime of the observation to be calculated in the
following format

2015-02-25T06:25:31

and `instrument` is one of the following choices:

ALICE

MIRO

OSIRIS_NAC

OSIRIS_WAC

VIRTIS_H

VIRTIS_M

DEBUG

TEST


so a full command will look like:

```
julia LOS.jl 2014-12-24T00:00:00 ALICE
```

###insitu.jl

This script computes values of different variables (such as number density) at the location of the
Rosetta spacecraft. To start this script do:

```
julia insitu.jl tStart tStop dt [t_unit]
```

With `tStart` and `tStop` are UTC times in the format yyyy-mm-ddTHH:MM:SS and `dt` is an integer number
for the step width between two data points. An optional `t_unit` argument can be given to specify the unit
of `dt`. This unit can be seconds, minutes, hours or days. If no unit is provided, seconds are assumed. 

#####Use any of the following valid keywords to specify a unit:
```
s sec second seconds
min minute minutes
h hour hours
d day days
```

So
```
julia insitu.jl 2015-08-01T00:00:00 2015-09-01T00:00:00 1 day
```
extracts data between August 1st 2015 and September 1st 2015 for every day at 00:00:00 hour.
Any of the following:
```
julia insitu.jl 2015-08-01T00:00:00 2015-09-01T00:00:00 10 m
julia insitu.jl 2015-08-01T00:00:00 2015-09-01T00:00:00 10 min
julia insitu.jl 2015-08-01T00:00:00 2015-09-01T00:00:00 10 minutes
```
does the same thing with a 10 minute resolution. You get the idea..
The results will be saved under `ices-desktop/work/output/`.


###interpolate-coords.jl

This script computes values of different variables at user defined coordinates.
The only input argument is the full path to the file containing the user coordinates.
This file must be in ASCII and contain nothing but the user specified coordinates
in a comma separated way.

The following is a valid format for the coordinate file:
```
0.0,1e-5,1001.2
0.0,0.0,100
100,100,100
```

Results are saved in `ices-desktop/work/output/`.




To define which DSMC data is used for this calculation you can set the parameter
'dataFile:' in the .userSettings.conf file. At runtime this file will be loaded and used
for the line of sight calculations.

Additionally you can also provide the keyword 'dataDir:' in .userSettings.conf. In this case
this is the full path to a directory containing multiple AMPS output files. The script will then
automatically load the best choice for the user defined time.
If the  .userSettings.conf file has both keywords, 'dataFile:' and 'dataDir:' it will choose
whatever is defined under 'dataFile:' as it is the more specific case.
When providing only 'dataDir:', you also need to define the keyword 'species:' in .userSettings.conf.
This is also true if there is only data from one specific species.


--------------------------------------------------------------------------------
CONFIGURATION
=============
You can configure all settings of the ices-desktop runs from within the `.userSettings.conf` file.
This file stores information on which `spice kernels` to load, which `DSMC files` to load, what gas species you
want to use and much more. During run time of any of the scripts described above, this file is parsed for
different keywords to get the necessary information.

The format of the `.userSettings.conf` file is just a stack of
`keyWord:parameter`
pairs.

The order of the keyword stack is not important and there is a list of all keywords that can be used at
the bottom of this paragraph.

You can add your own text for comments and such, just be sure to not use any
of the keywords from the list below. To modify the .userSettings.conf file you can use any text editor
you like.

If you have one `keyWord` doubly defined, the first one will be parsed and the
second one ignored.

Here the mandatory keyWords that have to be specified for each of the above scrips. Some of those are set to 
default values during the installation.

###LOS.jl
`workingDir:` directory where input files and the output of the calculations are stored (set at install time to 
ices-desktop/work).

`spicelib:` full path to the spice library (set at install time)

`kernelFile:` full path to the metafile containing all necessary spice kernels. (set at install time)

`meshFile:` full path to the shape model of 67P. (set at install time)

`dataFile:` full path to the DSMC output file which is to be used for the calculation (set at install time)

`dataDir:` full path to a directory with multiple DSMC output files. See comments below to see difference between dataDir
and DataFile.

`species:` your choice of species to be used for the calculation. Valid choices are H2O, CO2 or CO (or whatever species
are actually done in the DSMC case)


The line of sight calculation is performed for one specific date and time. If you know exactly which DSMC file you need
for this calculation you can specify this with the `dataFile:` keyword. However, you have to be sure to select a DSMC case
that is representative of the illumination conditions for your specific date and time.
To make things easier you can also define `dataDir:` in the .userSettings.conf file. In this directory you can have a full
set of DSMC output files, the LOS.jl script will automatically figure out which of those cases (including the species) is most suitable for that specific date.
This will select the right DSMC file according to heliocentric distance, solar longitude and solar latidude.
This is the recommended way of using the LOS.jl script.


###insitu.jl
`workingDir:` directory where input files and the output of the calculations are stored (set at install time to 
ices-desktop/work).

`spicelib:` full path to the spice library (set at install time)

`kernelFile:` full path to the metafile containing all necessary spice kernels. (set at install time)

`dataDir:` full path to a directory with multiple DSMC output files. See comments below to see difference between dataDir
and DataFile.

`species:` your choice of species to be used for the calculation. Valid choices are H2O, CO2 or CO (or whatever species
are actually done in the DSMC case). For insitu.jl you can also specify more than one species by having a comma separated list of arguments such as: `species:H2O,CO2,CO`.

Note that insitu.jl only accepts `dataDir:` and not `dataFile:` as parameter.


###interpolate_coords.jl
`workingDir:` directory where input files and the output of the calculations are stored (set at install time to 
ices-desktop/work).

`spicelib:` full path to the spice library (set at install time)

`kernelFile:` full path to the metafile containing all necessary spice kernels. (set at install time)

`dataFile:` full path to a directory with multiple DSMC output files. 

Note that interpolate_coords.jl only accepts `dataFile:` and not `dataDir:` as parameter. As there is no specified date
and time to when to extract the variables the exact DSMC file has to be specified.
The user coordinates have to be defined in meters and in the comet nucleus fixed reference frame. (Osiris reference frame)



List of Keywords:
----------------
Todo: quick description of each keyword.


`clibFile:` 

`kernelFile:`

`dataFile:`

`meshFile:`

`meshFileShadow:`

`doCheckShadow:`

`pltColorMap:`

`pltLevels:`

`pltTitle:`

`pltFontSize:`

`pltAdditionalBorderPx:`

`pltBlankBody:`

`variables:`


DEBUGGING
=========

Julia Blosc.jl installation sometimes does not work on first try. 2 sources of errors have been identified so far:

```
sudo apt-get install libc6-dev
```

or putting

```
cacert=/etc/ssl/certs/ca-certificates.crt
```

into 

```
~/.curlrc
```

has helped under Ubuntu.
