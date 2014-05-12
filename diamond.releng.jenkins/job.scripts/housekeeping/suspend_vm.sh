# Extract the name of the VM from the Jenkins job name
# Housekeeping.VM.suspend.ubuntu-10.04.4-desktop-amd64 --> ubuntu-10.04.4-desktop-amd64
VM=${JOB_NAME:24}

# get path to .vmx file
VMX=$(echo /scratch/vmware/diamond-${VM}/*.vmx)

# display the current state of the VM world
vmrun -T ws list
vmrun -T ws listSnapshots ${VMX}

# suspend the specified VM (this will return an error if the VM is not currently running)
set +e
vmrun -T ws suspend ${VMX}
RETVAL=$?
if [[ "${RETVAL}" -eq 0 ]]; then
    echo "set-build-description: running VM was suspended"
fi

