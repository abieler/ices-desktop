INSTALLATION
============

Julia:
------
  1) install julia version >= 0.4
     http://julialang.org/downloads/

  2) if it does not exist, create the file .juliarc.jl in your home
     directory (where you also have .bashrc etc)
     add the following line to the .juliarc.jl file:

     push!(LOAD_PATH, pwd())

     This includes the current directory in which julia is run
     to the LOAD_PATH. (The list of places where Julia looks for modules
     to load)

  3) a)
     OSX users: create the following symlink in order
     to be able to launch julia properly from the command line

     sudo ln -s /Applications/Julia-x.x.x.app/Contents/Resources/julia/bin/julia /usr/bin/julia

     where x.x.x is your version of the Julia install.

     Linux users: You are much cooler than OSX users. No such step necessary
     for you.

     b)
     open a new terminal or source your current session, then
     start julia from command line by typing:

     julia

     You should now be in the julia REPL (Read-Eval-Print-Loop) environment.
     Then execute the following commands one by one from within the Julia
     REPL to install necessary packages

     Pkg.add("DataFrames")
     Pkg.add("HDF5")
     Pkg.add("JLD")
     Pkg.add("PyPlot")
     Pkg.update()


Spice:
-----
  1) download and unzip the cspice library. (tested for version N0065) from
      https://naif.jpl.nasa.gov/naif/toolkit_C.html
  2) done


Git:
----
  1) Install git
  2) Set up git with some info if you are a first time user:
     a) git config --global user.name "John Doe"
     b) git config --global user.email johndoe@example.com


Ices-Desktop:

--------------------------------------------------------------------------------

CONFIGURATION
=============
Before you can run the line of sight integration tool you need to go through
a couple of configuration steps. All configurations can be done through the
Config.jl script which is found at:

AMPS/utility/LOS/Config.jl

Start a setup procedure by typing:

julia Config.jl --auto

This will run you through all the mandatory settings and the most useful
optional settings. Those user settings control e.g. where the computed results
are stored, which data file is to be loaded, what shape file is used etc.
Those settings are stored in ices-desktop/.userSettings.conf

After this script is finished you are good to go.
--------------------------------------------------------------------------------

RUNNING
=======

you have to run the main.jl script from within the src directory.

julia main.jl <date> <instrument>

Where <date> is the UTC datetime of the observation to be calculated in the
following format

2015-02-25T06:25:31

and <instrument> is one of the following choices:

ALICE
MIRO
OSIRIS_NAC
OSIRIS_WAC
VIRTIS_H
VIRTIS_M
DEBUG
TEST


so a full command will look like:

julia main.jl 2014-12-24T00:00:00 ALICE

--------------------------------------------------------------------------------



Some further notes on the .userSettings.conf file:
..................................................

The basic structure of the .userSettings.conf file is just a stack of
"keyWord:parameter"
pairs.

During runtime this ascii file is parsed for those keywords.
(Actually for "keyWord:")

The order of the keyword stack is not important.

You can add your own text for commenting and such, just be sure to not use any
of the keywords in that text.

If you have one keyWord doubly defined, the first one will be parsed and the
second one ignored.

You can edit this file with any text editor or via the Config.jl file.
The general use is to call

julia Config.jl --option

the following options are available ( * ) are mandatory setups)

--tmpdir <path to temporary directory> ( * )
  This directory is used to store files necessary for the LOS tool. It can be
  picked freely. In this directory the Config.jl file will create two subdirs
  'lib' and 'input'
  The 'lib' directory will contain shared libraries for spice and user defined
  c functions. (see below)
  The 'input' directory will be populated with the AMPS data files and the
  triangulated surface mesh files.
  It is not necessary to manually move any files into this directories, they
  will be updated on later steps by the Config.jl file.


--spicelib <path to cspice/lib/> ( * )
  Full path to the spice directory which contains the files
  cspice.a and csupport.a.
  Those files will then be copied into the 'lib' folder and compiled into a
  shared library (spice.so on linux, spice.dylib on OSX)


--kernelfile <full path to spice metafile>
  Full path and file name to a spice metafile that contains the full list
  of spice kernels to be loaded for the calculations
  --> the spice routine will call furnsh(metafile) on this file.


--clib <full path to custom c function definition>
  custom user file containing a function definition according to:

  void
  ColumnIntegrationFactor (double minSize,
                           double maxSize,
                           double r,
                           double * result){
  result[0]=666.0;

  // minSize = minimum size of dust particle
  // maxSize = maximum size of dust particle
  // r       = distance from observer along LOS
  // result  = provide a custom factor to be multiplied with the column density.
  // e.g. used for brightness calculation of dust grains
  }


--noclib
  do not use any shared c library
  If you never defined --clib this is unnecessary. It is only used to remove
  a c library that has been used in previous runs.


--meshfile        .ply file of the body surface mesh")
--meshfileshadow  .ply file of the body surface mesh for shadow calc.")
--docheckshadow   yes or no if shadow calculation is needed")
--datafile        .full path to h5 AMPS output file")
--clean           remove 'lib' and 'input' dirs in tmpfile")
--help            show this message"
