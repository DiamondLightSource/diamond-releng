# This script is intended to be sourced within another script
# to provide VM settings

# VM must be provided, or we error
echo "VM", ${VM:?}
export VMNAME=`echo /scratch/vmware/diamond-${VM}/*.vmx`

# Provide defaults where we can
echo "VMSNAPSHOT", ${VMSNAPSHOT:="base"}
echo "VMUTILS_DIR", ${VMUTILS_DIR:="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"}
echo "TEST_USER", ${TEST_USER:="tester"}
echo "TEST_PASSWORD", ${TEST_PASSWORD:="kesd-2ls-3s=Qq"}
echo "VMTYPE", ${VMTYPE:="-T ws"}
echo "VMHOST_IP", ${VMHOST_IP:=`/sbin/ifconfig vmnet1 | grep 'inet addr' | sed '-es,.*inet addr:,,' '-es, .*,,'`}
echo "VMHOST_TMP", ${VMHOST_TMP:=/tmp/squish_tmp_$USER/p$$}
mkdir -p $VMHOST_TMP

# set up a default OS type based on the path name
if echo $VMNAME | grep windows; then
  VMOSTYPE_DEFAULT=win
else
  VMOSTYPE_DEFAULT=linux
fi
if echo $VMNAME | grep i386; then
  VMOSTYPE_DEFAULT=${VMOSTYPE_DEFAULT}32
else
  VMOSTYPE_DEFAULT=${VMOSTYPE_DEFAULT}64
fi
echo "VMOSTYPE", ${VMOSTYPE:=$VMOSTYPE_DEFAULT} 
