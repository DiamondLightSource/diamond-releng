
: Options
set SCRATCH=C:\scratch
set AUT_NAME=dawn

: Setup AUT
: handle the case when either the application is at the top level in the zip, or is inside a single directory in the zip
date /T & time /T
%SCRATCH%\7z x -o%SCRATCH%\aut %SCRATCH%\aut.zip
if exist %SCRATCH%\aut\configuration (
  set AUT_DIR=%SCRATCH%\aut
  GOTO GotAUT
)
for /f %%a in ('dir /b %SCRATCH%\aut\*') do (
  if exist %SCRATCH%\aut\%%a%\configuration (
    set AUT_DIR=%SCRATCH%\aut\%%a%
    GOTO GotAUT
  )
)
echo "Could not find application in %SCRATCH%\aut\"
dir %SCRATCH%\aut\
:GotAUT
echo "found AUT_DIR=%AUT_DIR%"
: initialize
%AUT_DIR%\%AUT_NAME%.exe -initialize

# Some tests (namely those using P2, such as the P2 update tests), need the configuration
# writeable, therefore export AUT_DIR so that configuration and p2 directories can be
# copied out
# (Unlike in bash, nothing to explicitly export, but we rely on AUT_DIR being set)

: Setup JRE, use existing, or install standalone
: handle the case when either the application is at the top level in the zip, or is inside a single directory in the zip
echo %date% %time%
if exist %SCRATCH%\aut\jre\bin\java.exe (
  set JREDIR=%SCRATCH%\aut\jre
  GOTO GotJRE
)
for /f %%a in ('dir /b %SCRATCH%\aut\*') do (
  if exist %SCRATCH%\aut\%%a%\jre\bin\java.exe (
    set JREDIR=%SCRATCH%\aut\%%a%\jre
    GOTO GotJRE
  )
)
start /wait %SCRATCH%\jre.exe /s INSTALLDIR=%SCRATCH%\jre
set JREDIR=%SCRATCH%\jre
:GotJRE
echo "found JREDIR=%JREDIR%"
set PATH=%JREDIR%\bin;%PATH%

: Setup Squish
date /T & time /T
%SCRATCH%\7z x -o%SCRATCH%\tempsquish %SCRATCH%\squish.zip
move %SCRATCH%\tempsquish\squish-* %SCRATCH%\squish
rmdir %SCRATCH%\tempsquish

: This is essentially the command that is run by the UI setup in Squish to create the magic squishrt.jar
set SQUISHDIR=%SCRATCH%\squish
set squishserver=%SQUISHDIR%\bin\squishserver.exe
set java=%JREDIR%\bin\java.exe
set javaw=%JREDIR%\bin\javaw.exe
%java% -classpath "%SQUISHDIR%\lib\squishjava.jar;%SQUISHDIR%\lib\bcel.jar" com.froglogic.squish.awt.FixMethod "%JREDIR%\lib\rt.jar;%SQUISHDIR%\lib\squishjava.jar" "%SQUISHDIR%\lib\squishrt.jar"
copy /y "%SCRATCH%\squish_control\.squish-3-license" "%USERPROFILE%"
%squishserver% --config setJavaVM "%javaw%"
%squishserver% --config setJavaVersion "1.7"
%squishserver% --config setJavaHookMethod "jvm"
if exist %JREDIR%\bin\server\jvm.dll (
  %squishserver% --config setLibJVM "%JREDIR%\bin\server\jvm.dll"
) else (
  %squishserver% --config setLibJVM "%JREDIR%\bin\client\jvm.dll"
)
%squishserver% --config addAUT "%AUT_NAME%" "%AUT_DIR%"
%squishserver% --config setAUTTimeout 120

: Setup EPD Free
date /T & time /T
: XXX: This should really be dependent on whether we are using Base or full install. The base
: install should include this step, the full install should rely on picking it up as part of
: the tests
start /wait %SCRATCH%\epd_free.msi TARGETDIR=%SCRATCH%\epd_free /qr /norestart

mkdir %SCRATCH%\results
: start the server by running in a batch file so it can be run in the background
: For the uninitiated, the ^ is the batch escape character
date /T & time /T
echo %squishserver% ^> %SCRATCH%\results\squish_server.log 2^>^&1 > %SCRATCH%\runserver.bat
start %SCRATCH%\runserver.bat

set currenttestdir=org.dawnsci.squishtests
set SQUISH_SCRIPT_DIR=%SCRATCH%\squish_tests\%currenttestdir%\global_scripts
for /f %%a in ('dir /b %SCRATCH%\squish_tests\%currenttestdir%\suite_*') do (
  date /T & time /T
  %SQUISHDIR%\bin\squishrunner --testsuite %SCRATCH%\squish_tests\%currenttestdir%\%%a --reportgen stdout --reportgen xml2.1,%SCRATCH%\results\report_%currenttestdir%_%%a_xml2.1.xml --reportgen xmljunit,%SCRATCH%\results\report_%currenttestdir%_%%a_xmljunit.xml --resultdir %SCRATCH%\results  > %SCRATCH%\results\squish_runner_%%a.log 2>&1
)

REM Tests are finished, stop the server and wait for server process to finish
date /T & time /T
%squishserver% --stop
: wait for 15 seconds for the server to completely terminate  - this is the well known hacky way to do this on windows
: we need to do this so that all squish log and results files are closed, prior to zipping them up
ping -n 15 127.0.0.1 >nul

REM Create HTML versions of result files
date /T & time /T
for /f %%a in ('dir /b %SCRATCH%\results\*_xml2.1.xml') do (
  %SQUISHDIR%\python\python.exe %SCRATCH%\squish_control\squishxml2html.py --dir %SCRATCH%\results\ -i --prefix %SCRATCH%\results\ %SCRATCH%\results\%%a
)

REM zip up result ready to copy back
date /T & time /T
cd %SCRATCH%\results 
%SCRATCH%\7z a %SCRATCH%\results.zip .

date /T & time /T
echo "Finished running tests on the guest side"

