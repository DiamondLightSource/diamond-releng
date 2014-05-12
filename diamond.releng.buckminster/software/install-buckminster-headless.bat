REM ###
REM ### Install Buckminster headless on Windows. Edit this script before use.
REM ###

set arch=32
set today=2011-11-18
set version=3.7

set repository_buckminster=http://download.eclipse.org/tools/buckminster/headless-%version%
set repository_cloudsmith=http://download.cloudsmith.com/buckminster/external-%version%

set director_dir=S:\Science\DASC\buckminster\director
set director=%director_dir%\director.bat
set install_parent=S:\Science\DASC\buckminster
set install_suffix=%version%-%today%
set install_dir=%install_parent%\%arch%\%install_suffix%

IF NOT EXIST %install_dir% GOTO SKIPDEL
rmdir /s /q %install_dir%
:SKIPDEL

call %director% -repository %repository_buckminster% -destination %install_dir% -profile Buckminster -installIU org.eclipse.buckminster.cmdline.product

echo set the proxy by copying a valid .settings file from somewhere (any properly configured Eclipse install will do)
echo on
mkdir %install_dir%\configuration\.settings
copy %director_dir%\configuration\.settings\org.eclipse.core.net.prefs %install_dir%\configuration\.settings\org.eclipse.core.net.prefs
set buckminster=%install_dir%\buckminster.bat

echo off
REM #==========================================================
REM # install additional features into the just-installed Buckminster
REM # org.eclipse.buckminster.core.headless.feature : The Core functionality — this feature is required if you want to do anything with Buckminster except installing additional features.
REM # org.eclipse.buckminster.pde.headless.feature : Headless PDE and JDT support. Required if you are working with Java based components.
REM # org.eclipse.buckminster.git.headless.feature : Git
REM # org.eclipse.buckminster.subclipse.headless.feature : Subclipse
echo on

call %buckminster% install %repository_buckminster% org.eclipse.buckminster.core.headless.feature
echo on
call %buckminster% install %repository_buckminster% org.eclipse.buckminster.pde.headless.feature
echo on
call %buckminster% install %repository_buckminster% org.eclipse.buckminster.git.headless.feature
echo on
call %buckminster% install %repository_cloudsmith% org.eclipse.buckminster.subclipse.headless.feature

echo off
echo ***
echo WARNING! If this buckminster install is to be shared, make the install directory read-only so that it can be shared by multiple concurrent users
echo WARNING! If the directory is read-only, insert "-Dosgi.locking=none" into the last line of buckminster.bat thus: %VM% -Dosgi.locking=none %VMARGS%
echo ACTION: rename %install_parent%\%arch%\%install_suffix% to %install_parent%\%arch%\current
echo ***

