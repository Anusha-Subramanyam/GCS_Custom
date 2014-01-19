# QGroundControl 
## Open Source Micro Air Vehicle Ground Control Station


* Project:
<http://qgroundcontrol.org>

* Files:
<http://github.com/mavlink/qgroundcontrol>

* Credits:
<http://qgroundcontrol.org/credits>


## Documentation
For generating documentation, refer to /doc/README.

## Notes
Please make sure to delete your build folder before re-building. Independent of which 
build system you use (this is not related to Qt or your OS) the dependency checking and 
cleaning is based on the current project revision. So if you change the project and don't remove the build folder before your next build, incremental building can leave you with stale object files.

## QGC2.0 Tech Preview
Developers: In order to build the tech preview branch you need to:

    git clone https://github.com/mavlink/qgroundcontrol -b config qgc2
    git submodule init
    git submodule update

This procedure:

* Clones the config branch (which contains QGC2) from github into your qgc2 directory
* initializes all the submodules required for QGC, such as qupdate, the firmware installer
* gets the latest code for all submodules


# Build on Mac OSX

To build on Mac OSX (10.6 or later):
- - -
### Install SDL

1. Download SDL from:  <http://www.libsdl.org/release/SDL-1.2.14.dmg>
2. From the SDL disk image, copy the `sdl.framework` bundle to `/Library/Frameworks` directory (if you are not an admin copy to `~/Library/Frameworks`)

### Install QT
- - -
1. Download Qt 4.8+ from <http://download.qt-project.org/official_releases/qt/4.8/4.8.5/qt-mac-opensource-4.8.5.dmg > 
2. Double click the package installer and follow instructions: <http://qt-project.org/doc/qt-4.8/install-mac.html>

### Build QGroundControl
- - -
 (use clang compiler - not gcc)

1. From the terminal go to the `groundcontrol` directory
2. Run `qmake qgroundcontrol.pro -r -spec unsupported/macx-clang CONFIG+=x86_64`
3. Run `make -j4`


# Build on Linux 

To build on Linux (directions specific to Ubuntu derivatives):
Execute the following commands from the location where you will want to put the qgroundcontrol source code
- - -
    $ sudo apt-get install phonon libqt4-dev libphonon-dev libphonon4 phonon-backend-gstreamer qtcreator libsdl1.2-dev libflite1 flite1-dev build-essential libopenscenegraph-dev libudev-dev
    $ git clone https://github.com/mavlink/qgroundcontrol.git
    $ cd qgroundcontrol
    $ git submodule init
    $ git submodule update

* Go to `libs/thirdParty/libxbee` 
  * Install libxbee: `sudo make install`
* Either build from the command line
  * `qmake;make -j4`
* Or build within Qt Creator
  * Launch it via the command line `qtcreator` or in Ubuntu's Unity desktop at Ubuntu Application Menu -> Development -> Qt Creator
  * Open the `/qgroundcontrol.pro` project using QtCreator Menu File -> Open File or Project..
  * Build by pressing the green play button in the bottom left.

# Build on Windows
- - -

__GNU GCC / MINGW IS UNTESTED, COULD WORK WITH
VISUAL STUDIO 2008 / 2010 EXPRESS EDITION (FREE!)__

Steps for Visual Studio 2008 / 2010:

Windows XP/7:

1. Download and install the Qt libraries for Windows from https://qt.nokia.com/downloads/ (the Visual Studio 2008 or 2010 version as appropriate)

2. Download and install Visual Studio 2008 or 2010 Express Edition (free) from https://www.microsoft.com/visualstudio. If using Visual Studio 2010, make sure you are running at least SP1. There is a linking error you'll encounter otherwise that will prevent compilation.

3. Go to the QGroundControl folder and then to thirdParty/libxbee and build it following the instructions in win32.README

4. Open the Qt Command Prompt program (should be in the Start Menu), navigate to the source folder of QGroundControl and create the Visual Studio project by typing `qmake -tp vc qgroundcontrol.pro`

5. Now start Visual Studio and load the qgroundcontrol.vcproj if using Visual Studio 2008 or qgroundcontrol.vcxproj if using Visual Studio 2010

6. Compile and edit in Visual Studio. If you need to add new files, add them to qgroundcontrol.pro and re-run `qmake -tp vc qgroundcontrol.pro`


## Repository Layout
    qgroundcontrol:
	    demo-log.txt
	    license.txt 
	    qgcunittest.pro - For the unit tests.
	    qgcunittest.pro.user
	    qgcvideo.pro
	    qgroundcontrol.pri - Used by qgroundcontrol.pro
	    qgroundcontrol.pro - Project opened in QT to run qgc.
	    qgroundcontrol.pro.user 
	    qgroundcontrol.qrc - Holds many images.
	    qgroundcontrol.rc - line of code to point toward the images
	    qserialport.pri - generated by qmake.
	    testlog.txt - sample log file
	    testlog2.txt - sample log file
	    user_config.pri.dist - Custom message specs to be added here. 
    data: 
	    Maps from yahoo and kinect and earth. 
    deploy: 
	    Install and uninstall for win32.
	    Create a debian packet.
	    Create .DMG file for publishing for mac.
	    Audio test on mac.	
    doc: 
	    Doxyfile is in this directory and information for creating html documentation for qgc.
    files: 
	    Has the audio for the vehicle and data output. 
		    ardupilotmega: 
			    widgets and tool tips for pilot heading for the fixed wing.
			    tooltips for quadrotor
		    flightgear:
			    Aircraft: 
				    Different types of planes and one jeep. 
			    Protocol: 
				    The protocol for the fixed_wings and quadrotor and quadhil.holds info about the fixed wing yaw, roll etc. 	
			    Quadrotor:
			        Again holds info about yaw, roll etc.
			    Pixhawk:
			        Widgets for hexarotor. Widgets and tooltips for quadrotor.
			    vehicles: 
			        different vehicles. Seems to hold the different kinds of aircrafts as well as files for audio and the hexarotor and quadrotor.
			    widgets: 
			        Has a lot of widgets defined for buttons and sliders.

    images: 
	    For the UI. Has a bunch of different images such as images for applications or actions or buttons.
    lib: 
	    SDL is located in this direcotry. 
	Msinttypes: 
	    Defines intteger types for microsoft visual studio. 
	sdl:
	    Information about the library and to run the library on different platforms. 
    mavlink: 
	    The files for the library mavlink. 
    qgcunittest: 
	    Has the unittests for qgc
    settings: 
	    Parameter lists for alpha, bravo and charlie. Data for stereo, waypoints and radio calibration. 
    src:
	    Code for QGCCore, audio output, configuration, waypoints, main and log compressor.
	apps
	    Code for mavlink generation and for a video application.
	comm
	    Code for linking to simulation, mavlink, udp, xbee, opal, flight gear and interface.
	Has other libraries. Qwt is in directory named lib. The other libraries are in libs.
	lib
	    qwt library
	libs
	    eigen, opmapcontrol, qestserialport, qtconcurrent, utils.
	input
	    joystick and freenect code.
	plugins
	    Qt project for PIXHAWK plugins.
	uas
	    Ardu pilot, UAS, mavlink factory, uas manager, interface, waypoint manager and slugs.
	ui
	    Has code for data plots, waypoint lists and window congfiguration. All of the ui code.
thirdParty: 
	    Library called lxbee.
	    Library called QSerialPort.
