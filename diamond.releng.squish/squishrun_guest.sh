#!/bin/bash
set -o posix # posix mode so that error setting inherit to subshells
set -eux # error, unset and echo

# Options
echo "SCRATCH", ${SCRATCH:="/scratch"}
echo "AUT_NAME=${AUT_NAME}"
echo "DISPLAY", ${DISPLAY:=":0.0"}

# Install squish in the Guest, $1 should be guest's JRE directory, $2 the aut name, $3 aut directory
# Sets SQUISHDIR (essentially as return)
function install_squish()
{
  echo "`date +"%a %d/%b/%Y %H:%M:%S"` install_squish start"
  local jredir=$1
  local aut_name=$2
  local aut_dir=$3
  local java="${jredir}/bin/java"

  unzip -q -d $SCRATCH/tempsquish $SCRATCH/squish.zip
  : Remove version from folder name
  mv $SCRATCH/tempsquish/* $SCRATCH/squish
  rmdir $SCRATCH/tempsquish

  ## Setup squish
  # This is essentially the command that is run by the UI setup in Squish to create the magic squishrt.jar
  SQUISHDIR="$SCRATCH/squish"
  local squishserver="$SQUISHDIR/bin/squishserver"
  java_version=`"$java" -version 2>&1 | grep 'java version' | sed '-es,[^"]*"\([^"]*\)",\1,'`
  echo "`date +"%a %d/%b/%Y %H:%M:%S"` install_squish FixMethod"
  "$java" \
    -classpath "${SQUISHDIR}/lib/squishjava.jar:${SQUISHDIR}/lib/bcel.jar" \
    com.froglogic.squish.awt.FixMethod \
    "${jredir}/lib/rt.jar:${SQUISHDIR}/lib/squishjava.jar" \
    "${SQUISHDIR}/lib/squishrt.jar"
  cp "$SCRATCH/squish_control/.squish-3-license" ~/.squish-3-license
  $squishserver --config setJavaVM "$java" 
  $squishserver --config setJavaVersion "$java_version"
  $squishserver --config setJavaHookMethod "jvm"
  $squishserver --config setLibJVM "`find $jredir -name libjvm.so | head -1`"
  $squishserver --config addAUT "$aut_name" "$aut_dir"
  $squishserver --config setAUTTimeout 120
  echo "`date +"%a %d/%b/%Y %H:%M:%S"` install_squish end"
}

: Setup AUT
: handle the case when either the application is at the top level in the zip, or is inside a single directory in the zip
echo "`date +"%a %d/%b/%Y %H:%M:%S"` unzip aut"
unzip -q -d $SCRATCH/aut $SCRATCH/aut.zip
if test -e $SCRATCH/aut/configuration ; then
  AUT_DIR=$SCRATCH/aut
elif test -e $SCRATCH/aut/*/configuration ; then
  AUT_DIR=$SCRATCH/aut/*
else
  echo "Could not find application in $SCRATCH/aut/"
  ls -la $SCRATCH/aut/
fi
# initialize, then make aut directory read-only
${AUT_DIR}/${AUT_NAME} -initialize
chmod -R a-w ${AUT_DIR}/

# Some tests (namely those using P2, such as the P2 update tests), need the configuration
# writeable, therefore export AUT_DIR so that configuration and p2 directories can be
# copied out
export AUT_DIR

: Setup JRE, use existing, or install standalone
: handle the case when either the application is at the top level in the zip, or is inside a single directory in the zip
echo "`date +"%a %d/%b/%Y %H:%M:%S"` set up JRE"
if test -e $SCRATCH/aut/jre/bin/java ; then
  JREDIR=$SCRATCH/aut/jre
elif test -e $SCRATCH/aut/*/jre/bin/java ; then
  JREDIR=$SCRATCH/aut/*/jre
else
  chmod +x $SCRATCH/jre.bin
  (mkdir -p $SCRATCH/tempjre && cd $SCRATCH/tempjre && $SCRATCH/jre.bin)
  : Remove version from folder name
  mv $SCRATCH/tempjre/* $SCRATCH/jre
  rmdir $SCRATCH/tempjre
  JREDIR=$SCRATCH/jre
fi
export PATH=${JREDIR}/bin:${PATH}

: Setup Squish
install_squish $JREDIR $AUT_NAME $AUT_DIR

: Setup EPD Free
echo "`date +"%a %d/%b/%Y %H:%M:%S"` setup EPD free"
$SCRATCH/epd_free.sh -p $SCRATCH/epd_free -b


# There are some incompatibilities between the Unity app menu and eclipse
# While in general it works mostly ok with newer Eclipse, there are still 
# strange occurrences, such as random menu order changes
# See 
# https://bugs.launchpad.net/ubuntu/+source/appmenu-gtk/+bug/660314,
# https://bugs.eclipse.org/bugs/show_bug.cgi?id=330563
# https://bugs.launchpad.net/eclipse/+bug/618587
UBUNTU_MENUPROXY=0
export UBUNTU_MENUPROXY


# Run Squish, with the server output prefixed with 'S: ' and the runner's with 'R: '
export DISPLAY
mkdir -p $SCRATCH/results
echo "`date +"%a %d/%b/%Y %H:%M:%S"` start squish server"
## ($SQUISHDIR/bin/squishserver 2>&1 | tee $SCRATCH/results/squish_server.log | sed '-es,^,S: ,') & ##  original line which floods Jenkins console log
($SQUISHDIR/bin/squishserver > $SCRATCH/results/squish_server.log 2>&1) &
squish_server_pid=$!

squish_tests_locations=$(ls -1 ${SCRATCH}/squish_tests | sort)
echo "squish_tests_locations=${squish_tests_locations}"
for squish_test_location in ${squish_tests_locations}; do
    export SQUISH_SCRIPT_DIR=$SCRATCH/squish_tests/${squish_test_location}/global_scripts
    # test suites whose name ends in _diamond are not suitable for running on the VMs
    suites=`find ${SCRATCH}/squish_tests/${squish_test_location} -mindepth 1 -maxdepth 1 -type d -name "suite_*" ! -name "*_diamond" | xargs -i basename {}`
    for suite in $suites; do
      echo "`date +"%a %d/%b/%Y %H:%M:%S"` running $squish_test_location/$suite"
      ($SQUISHDIR/bin/squishrunner \
        --testsuite $SCRATCH/squish_tests/$squish_test_location/$suite \
        --reportgen stdout \
        --reportgen xml2.1,$SCRATCH/results/report_${squish_test_location}_${suite}_xml2.1.xml  \
        --reportgen xmljunit,$SCRATCH/results/report_${squish_test_location}_${suite}_xmljunit.xml \
        --resultdir $SCRATCH/results \
        > $SCRATCH/results/squish_runner_${squish_test_location}_${suite}.log 2>&1) || true
        ## 2>&1 | tee $SCRATCH/results/squish_runner_${squish_test_location}_${suite}.log | sed '-es,^,R: ,' )  ## original line which floods Jenkins console log
    done
done

# Tests are finished, stop the server and wait for server process to finish
echo "`date +"%a %d/%b/%Y %H:%M:%S"` stop squish server"
$SQUISHDIR/bin/squishserver --stop
wait $squish_server_pid

# Create HTML versions of result files
echo "`date +"%a %d/%b/%Y %H:%M:%S"` create HTML versions of test files"
xml21files=`find $SCRATCH/results/ -name \*_xml2.1.xml`
python $SCRATCH/squish_control/squishxml2html.py --dir $SCRATCH/results/ -i --prefix $SCRATCH/results/ $xml21files 

# zip up result ready to copy back
echo "`date +"%a %d/%b/%Y %H:%M:%S"` zip results ready to copy back"
(cd $SCRATCH/results && zip -r $SCRATCH/results.zip .)

echo "`date +"%a %d/%b/%Y %H:%M:%S"` Finished running tests on the guest side"
