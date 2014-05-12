# Helper functions

#############################
### Test if VM is windows ###
#############################
function vm_is_windows() {
    if [[ "${VMOSTYPE}" == win* ]]; then
        return 0
    else
        return 1
    fi
    }

#######################################
### Set platform-specific variables ###
#######################################
function set_platform_variables() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` set_platform_variables"
    if vm_is_windows; then
      echo "DOTEXE", ${DOTEXE:=".exe"} 
      echo "SLASH", ${SLASH:="\\"} 
      echo "PATHSEP", ${PATHSEP:=";"} 
      echo "GUESTROOT", ${GUESTROOT:="C:\\"}  
      : GUESTHOME will be evaluated on the guest
      echo "GUESTHOME", ${GUESTHOME='%HOMEDRIVE%%HOMEPATH%'} 
    else
      echo "DOTEXE", ${DOTEXE:=""} 
      echo "SLASH", ${SLASH:="/"}
      echo "PATHSEP", ${PATHSEP:=":"} 
      echo "GUESTROOT", ${GUESTROOT:="/"} 
      : GUESTHOME will be evaluated on the guest
      echo "GUESTHOME", ${GUESTHOME='$HOME'} 
    fi
    echo "VMGUEST_SCRATCH_NATIVE", ${VMGUEST_SCRATCH_NATIVE:="${GUESTROOT}scratch"}
    echo "VMGUEST_SCRATCH", ${VMGUEST_SCRATCH:="/scratch"}
    }

###########################
### Set SSH environment ###
###########################
function set_SSH_envionment() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` set_SSH_envionment"
    # SSH settings
    echo "SSH_TESTER_ID_RSA", ${SSH_TESTER_ID_RSA:="${VMUTILS_DIR}/id_rsa"}
    : set permissions correctly on id_rsa, git sometimes checks it out with too many
    chmod 0600 ${SSH_TESTER_ID_RSA}
    # -i means use this ID
    # -F is location for config, we don't want to use config of ~/.ssh
    # -o StrictHostKeyChecking=no means that we don't get interrupted by known_host missing/mismatched
    # -o UserKnownHostsFile=/dev/null means that we discard any updates to known_hosts and don't read/write them from ~/.ssh/known_hosts
    echo "SSH_OPTIONS", ${SSH_OPTIONS:="-o LogLevel=quiet -o IdentityFile=$SSH_TESTER_ID_RSA -F /dev/null -o StrictHostKeyChecking=no -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o User=$TEST_USER"}
    }

###########################################
### Copy a file from Guest back to Host ###
###########################################
# Copy $1, a file on guest, to $2 a file on host
# Destination must be a file name, unlike cp you cannot target a folder, nor have more than one source
function vmcopy_guest_to_host() {
    # make sure guest ip is up to date
    vm_setup_ip
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Copying file $1 on Guest to $2 on Host"
    if vm_is_windows; then
        echo -e "get $1 $2" > ${VMHOST_TMP}/vmcopy_guest_to_host
        sftp -b ${VMHOST_TMP}/vmcopy_guest_to_host ${SSH_OPTIONS} ${VM_GUEST_IP}
    else
        scp ${SSH_OPTIONS} ${VM_GUEST_IP}:"$1" "$2"
    fi
    }

######################################
### Copy a file from Host to Guest ###
######################################
# Copy $1, a file on host, to $2 a full file name on guest
# Destination must be a file name, unlike cp you cannot target a folder, nor have more than one source
function vmcopy_host_to_guest() {
    # make sure guest ip is up to date
    vm_setup_ip
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Copying file $1 on Host to $2 on Guest"
    if vm_is_windows; then
        echo -e "put $1 $2" > ${VMHOST_TMP}/vmcopy_host_to_guest
        sftp -b ${VMHOST_TMP}/vmcopy_host_to_guest ${SSH_OPTIONS} ${VM_GUEST_IP}
    else
        scp ${SSH_OPTIONS} "$1" ${VM_GUEST_IP}:"$2"
    fi
    }


function vmrun_cmd() 
{
  local command="$1"
  shift
  date +"%a %d/%b/%Y %H:%M:%S"
  vmrun -gu "$TEST_USER" -gp "$TEST_PASSWORD" $VMTYPE $command "$VMNAME" "$@"
}

function vmssh()
{
  # make sure guest ip is up to date
  vm_setup_ip
  date +"%a %d/%b/%Y %H:%M:%S"
  if vm_is_windows; then
    # freesshd doesn't run programs within a shell like opensshd does, so
    # each command we run we need to provide a shell to run it in
    ssh ${SSH_OPTIONS} ${VM_GUEST_IP} 'cmd.exe' '/c' "$@"
  else
    ssh ${SSH_OPTIONS} ${VM_GUEST_IP} "$@"
  fi
}

# Setup the guest IP and set the variable VM_GUEST_IP to that address
# The IP address used will be derived from the VNC port in use. 
function vm_setup_ip()
{
  # Note you cannot use ssh based commands in this function as they require
  # the IP address to be fully detected
  if [[ "x${VM_GUEST_IP:-unset}" == "xunset" ]]; then
    date +"%a %d/%b/%Y %H:%M:%S"
    # Calculate the IP address to use.
    host_24_bit=`echo $VMHOST_IP | sed '-es,\.[0-9]*$,,'`
    # This has as an input something like the following (in the VMX file)
    # RemoteDisplay.vnc.port = "5951"
    # And returns the 51
    vnc_port=`grep 'RemoteDisplay.vnc.port' $VMNAME | grep '"59' | sed '-es,[^"]*"59,,' '-es,".*,,'`
    guest_ip="${host_24_bit}.${vnc_port}"

    local f=$VMHOST_TMP/guestip_set_$$
    if vm_is_windows; then
      # Set the IP address, this only works if UAC is disabled as netsh requires elevation
      printf "netsh interface ip set address name=\"Local Area Connection\" static ${guest_ip} 255.255.255.0 ${VMHOST_IP} 1\r\n" > $f
      vmrun_cmd copyFileFromHostToGuest $f "${VMGUEST_SCRATCH_NATIVE}\\guestip_set.bat"
      rm $f
      vmrun_cmd runProgramInGuest -interactive -activeWindow "${VMGUEST_SCRATCH_NATIVE}\\guestip_set.bat"
    else
      # Set the IP address, this only works if sudoers is setup to allow it properly
      echo "set -ex" > $f
      echo "sudo dhclient -r" >> $f
      echo "sudo ifconfig -v eth0 ${guest_ip} netmask 255.255.255.0 up" >> $f
      echo "sudo route add default gw ${VMHOST_IP} eth0" >> $f
      echo "ifconfig eth0" >> $f
      vmrun_cmd copyFileFromHostToGuest $f "${VMGUEST_SCRATCH_NATIVE}/guestip_set"
      rm $f
      vmrun_cmd runProgramInGuest "/bin/bash" "${VMGUEST_SCRATCH_NATIVE}/guestip_set"
    fi

    # On windows and older linux there is a delay before we can route to the newly assigned IP
    sleep 20

    # If we get here ok we assume that the IP address is now correctly setup, so assign it to the "return" value
    VM_GUEST_IP=${guest_ip}
    
  fi
  return 0
}

# Unzip archive in $1 to directory in $2
function vmunzip()
{
  if vm_is_windows; then
    vmssh "${VMGUEST_SCRATCH_NATIVE}\\7z.exe" x "-o$2" "$1"
  else
    vmssh /usr/bin/unzip -q -d "$2" "$1"
  fi
}

# Zip to archive in $1 all files in $3- with the cwd set to $2
function vmzip()
{
  if vm_is_windows; then
    echo "TODO"
    false
  else
    zipfile=$1
    working_dir=$2
    shift 2
    vmssh "cd $working_dir && /usr/bin/zip -r $zipfile $@"
  fi
}

# Move $1 to $2
function vmmove()
{
  if vm_is_windows; then
    vmssh move "$1" "$2"
  else
    vmssh mv "$1" "$2"
  fi
}

# Move $1 to $2
function vmcopy()
{
  if vm_is_windows; then
    vmssh copy "$1" "$2"
  else
    vmssh cp "$1" "$2"
  fi
}

# perform test -e $1 (adjusted for platform) on guest
function vmfileexists()
{
  if vm_is_windows; then
    echo "TODO"
    return 1 
  else
    vmssh test -e "$1"
  fi
}

####################################
### Create a directory on the VM ###
####################################
# Create dir $1 on guest, including parents when needed
function vmmkdir() {
    echo "Creating directory $1 on guest ${VM}"
    if vm_is_windows; then
        vmssh mkdir "$1"
    else
        vmssh mkdir -p "$1"
    fi
    }

####################
### Start the VM ###
####################
# Revert to and run the VM from the snapshot
function vmstart() {
    # Start up vmware headless
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Listing snapshots and running VMs before anything else happens (this may help debug a failed build)"
    vmrun $VMTYPE listSnapshots $VMNAME
    vmrun $VMTYPE list
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Reverting to snapshot $VMSNAPSHOT"
    vmrun $VMTYPE revertToSnapshot $VMNAME $VMSNAPSHOT
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` List all running VMs before starting (this may help debug a failed build)"
    vmrun $VMTYPE list
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Starting VM ..."
    if [[ -n "${nice_setting_vmrun:-}" ]]; then
        vmrun="nice -n ${nice_setting_vmrun} vmrun"
    else
        vmrun="vmrun"
    fi
    ${vmrun} $VMTYPE start $VMNAME nogui
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` List all running VMs after starting (this may help debug a failed build)"
    vmrun $VMTYPE list
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Started VM Ware image, don't forget to terminate it"
    echo "Can be stopped with: \"vmrun $VMTYPE stop $VMNAME\""
}

###################
### Stop the VM ###
###################
function vmstop() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Listing running VMs before and after stopping"
    vmrun $VMTYPE list
    vmrun $VMTYPE stop $VMNAME
    vmrun $VMTYPE list
    }

####################
### Pause the VM ###
####################
function vmpause() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Listing running VMs before and after pausing"
    vmrun $VMTYPE list
    vmrun $VMTYPE pause $VMNAME
    vmrun $VMTYPE list
}

######################
### Suspend the VM ###
######################
function vmsuspend() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Listing running VMs before and after suspending"
    vmrun $VMTYPE list
    vmrun $VMTYPE suspend $VMNAME
    vmrun $VMTYPE list
    }

#############################################################
### Take a snapshot with the name provided as an argument ###
#############################################################
function vmsnapshot() {
    # Start up vmware headless
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` Taking a snapshot named $1, Listing snapshots before and after (this may help debug a failed build)"
    vmrun $VMTYPE listSnapshots $VMNAME
    vmrun $VMTYPE snapshot $VMNAME $1
    vmrun $VMTYPE listSnapshots $VMNAME
    }
