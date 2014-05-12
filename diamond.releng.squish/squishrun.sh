#!/bin/bash
date +"%a %d/%b/%Y %H:%M:%S"
set -o posix # posix mode so that error setting inherit to subshells
set -eux # error, unset and echo

# source functions useful for this script 
. ${SQUISH_CONTROL_DIR}/utils/squish_functions_basic.sh
. ${SQUISH_CONTROL_DIR}/utils/squish_functions_vm.sh
# set environment variables describing the VM
. ${SQUISH_CONTROL_DIR}/utils/vmoptions.sh

set_platform_variables
set_SSH_envionment

# Options for this script
echo "SQUISH_RESULTDIR", ${SQUISH_RESULTDIR:=$WORKSPACE/results}

: VM_POST_SNAPSHOT must be set to something for a snapshot, or blank to skip
echo "VM_POST_SNAPSHOT", ${VM_POST_SNAPSHOT:=""}

# Start the VM, but first register a handler
# to pause the VM when this script ends
function endtest()
{
  echo "Running cleanup code"
  vmsuspend
  rm -rf "$VMHOST_TMP"
}
trap 'endtest' EXIT
vmstart

#######################################
# Copy all required files to the VM ###
#######################################
copy_control
copy_squish
if [[ ! application_zip_includes_jre ]]; then
    copy_jre
fi
copy_epd_free
copy_application
copy_tests

## Bootstrap testing by unzipping squish_control and squish_tests and running script
vmunzip "${VMGUEST_SCRATCH}/squish_control.zip" "${VMGUEST_SCRATCH}/squish_control"
vmunzip "${VMGUEST_SCRATCH}/squish_tests.zip" "${VMGUEST_SCRATCH}/squish_tests"
if vm_is_windows; then
  vmssh "${VMGUEST_SCRATCH}\\squish_control\\squishrun_guest.bat"
else
  vmssh "AUT_NAME=$SQUISH_AUT_NAME /bin/bash ${VMGUEST_SCRATCH}/squish_control/squishrun_guest.sh 2>&1 | tee ${VMGUEST_SCRATCH}/log"
fi

## Copy results back to host and make HTML as well
vmcopy_guest_to_host $VMGUEST_SCRATCH/results.zip $VMHOST_TMP/results.zip 
mkdir -p $SQUISH_RESULTDIR
(cd $SQUISH_RESULTDIR && unzip $VMHOST_TMP/results.zip)

## Take a snapshot of the result
## XXX: Should we only do this if we have a test failures? 
if test -n "$VM_POST_SNAPSHOT" ; then
  vmsnapshot "$VM_POST_SNAPSHOT" || echo "Failed to take snapshot"
fi

echo "Test script complete, only exit traps left to run"
