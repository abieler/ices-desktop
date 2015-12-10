INSTALLATION
============

Julia
------

  1. install julia version >= 0.4
  
     http://julialang.org/downloads/

  2. if it does not exist, create the file .juliarc.jl in your home
     directory (where you also have .bashrc etc)
     add the following line to the .juliarc.jl file:

     ```
     push!(LOAD_PATH, pwd())
     ```

     This includes the current directory in which julia is run
     to the LOAD_PATH. (The list of places where Julia looks for modules
     to load)

  3. 
  
     a)
     **OSX users**: create the following symlink in order
     to be able to launch julia properly from the command line
     
    ```
    sudo ln -s /Applications/Julia-x.x.x.app/Contents/Resources/julia/bin/julia /usr/bin/julia
    ```

     where x.x.x is your version of the Julia install.

     **Linux users**: You are much cooler than OSX users. No such step necessary
     for you.

     b)
     open a new terminal or source your current session, then
     start julia from command line by typing:

     julia

     You should now be in the julia REPL (Read-Eval-Print-Loop) environment.
     Then execute the following commands one by one from within the Julia
     REPL to install necessary packages
     ```
     Pkg.add("DataFrames")
     Pkg.add("HDF5")
     Pkg.add("JLD")
     Pkg.add("PyPlot")
     Pkg.update()
     ```
     
     You can exit the Julia REPL by typing exit(), quit() or CTRL+D


Git
----
  Git is not necessary to install, you can simply download the ices-desktop tool from this page.
  However, if you install git you will be able to update the tool to the newest version via git
  through the command line using `git pull`, which downloads the latest version of the tool. If you
  install git and are a first time user, provide the following information by command line:

  ```
   git config --global user.name "John Doe"
   
   git config --global user.email johndoe@example.com
  ```

Ices-Desktop
------------
  You can either download the ices-desktop tool by clicking the "Download ZIP" button on this page, or
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

Spice
-----
  1. Download and unzip the cspice library (the file **cspice.tar.Z**) from
      https://naif.jpl.nasa.gov/naif/toolkit_C.html
  2. Move the extracted folder "cspice" into the ices-desktop folder, parallel to "src".
  3. Get necessary spice kernel files from andre (they are not public) or if you know your way around spice, get your own spice      kernels.

Additional Data
---------------
  Request additional data from andre. This includes the mesh files of the CG shape model and the DSMC data files.

--------------------------------------------------------------------------------

CONFIGURATION
=============
Before you can run the line of sight integration tool you need to go through
a couple of configuration steps. All configurations can be done through the
Config.jl script which is found at:

ices-desktop/Config.jl

Start a setup procedure by typing:

julia Config.jl --auto

This will run you through all the mandatory settings and the most useful
optional settings. Those user settings control e.g. where the computed results
are stored, which data file is to be loaded, what shape file is used etc.
Those settings are stored in ices-desktop/.userSettings.conf
**Please read the additional information about the configuration settings
at the bottom of this document.**

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

The .userSettings.conf file is just a stack of
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
The general use is to call:
```
julia Config.jl --option
```
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
  
  (your/path/to/ices-desktop/cspice/lib if you followed the installation instructions)
  
  Those files will then be copied into the 'lib' folder and compiled into a
  shared library (spice.so on linux, spice.dylib on OSX)
  

--kernelfile <full path to spice metafile> ( * )
  Full path and file name to a spice metafile that contains the list
  of spice kernels to be loaded
  --> the spice routine will call furnsh(metafile) on this file.
  
--datafile <full path to DSMC output file> ( * )
  specify the full path to the DSMC data file you want to be used for the LOS calculation.
  A copy of this file will then be placed into the "tmpdir" specified above. If the AMPS
  file is not in the .h5 format, you will be asked if you want to convert it into .h5
  --> this conversion is necessary, but it will overwrite previous .h5 files.
  
--meshfile <full path to shape model .ply file>
  A copy of the shape model .ply file will be put into the tmpdir.


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

--docheckshadow   yes or no if shadow calculation is needed. 
  If yes, the line of sight calculation will skip values along
  the LOS which are in the shadow. If no, the full LOS will be computed.


--meshfileshadow  .ply file of the body surface mesh for shadow calculation. You can provide a coarser
  resolution of the actual shape model mesh for the shadow calculation. This will decrease the CPU time
  for the LOS calculations.
  


--clean           remove 'lib' and 'input' dirs in tmpfile")
--help            show this message"
