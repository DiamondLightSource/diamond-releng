REM ###
REM ### Installs the Eclipse Buckminster Headless application on Windows.
REM ### Pre-requisites: Download and unzip the director application (see https://www.eclipse.org/buckminster/downloads.html)
REM ###
REM ### READ AND UNDERSTAND WHAT THIS DOES BEFORE RUNNING!
REM ###
REM ### Note: this script supercedes the earlier install-buckminster-headless.bat script
REM ###

# set the location where you unzipped the director application
set director_dir=S:\Science\DASC\buckminster\director
set director=%director_dir%\director.bat

# set your local proxy (if required)
set http_proxy=http://wwwcache.rl.ac.uk:8080/
set https_proxy=http://wwwcache.rl.ac.uk:8080/

# specify what version you want to download; the architecture (32 or 64) is the architecture of your Java JVM
set arch=64
set today=2015-10-16
set version=4.4

# specify where you want to install Buckminster
set install_parent=S:\Science\DASC\buckminster
set install_suffix=%version%-%today%
set buckminster_install_dir=%install_parent%\%arch%\%install_suffix%

IF NOT EXIST %buckminster_install_dir% GOTO SKIPDEL
rmdir /s /q %buckminster_install_dir%
:SKIPDEL

set repository_buckminster=http://download.eclipse.org/tools/buckminster/headless-%version%

echo off
REM #==========================================================
REM # install Buckminster, using the director application
echo on

call %director% -repository %repository_buckminster% -destination %buckminster_install_dir% -profile Buckminster -installIU org.eclipse.buckminster.cmdline.product

echo off
REM #==========================================================
REM # install additional features into the just-installed Buckminster
REM # org.eclipse.buckminster.core.headless.feature : The Core functionality — this feature is required if you want to do anything with Buckminster except installing additional features.
REM # org.eclipse.buckminster.pde.headless.feature : Headless PDE and JDT support. Required if you are working with Java based components.
REM # org.eclipse.buckminster.git.headless.feature : Git
REM # org.eclipse.buckminster.subclipse.headless.feature : Subclipse
echo on

set buckminster=%buckminster_install_dir%\buckminster.bat
call %buckminster% install %repository_buckminster% org.eclipse.buckminster.core.headless.feature
echo on
call %buckminster% install %repository_buckminster% org.eclipse.buckminster.pde.headless.feature
echo on
call %buckminster% install %repository_buckminster% org.eclipse.buckminster.git.headless.feature

echo off
echo ***
echo WARNING! If this buckminster install is to be shared, make the install directory read-only so that it can be shared by multiple concurrent users
echo WARNING! If the directory is read-only, insert "-Dosgi.locking=none" into the last line of buckminster.bat thus: %VM% -Dosgi.locking=none %VMARGS%
echo ACTION: at DLS at least, rename %install_parent%\%arch%\%install_suffix% to %install_parent%\%arch%\gdamaster
echo ***

