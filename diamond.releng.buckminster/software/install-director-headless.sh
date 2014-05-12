#!/bin/bash
###
### Installs the Eclipse Buckminster Director application.
### READ AND UNDERSTAND WHAT THIS DOES BEFORE RUNNING!
###

# If you are:
# (1) a Diamond Light Source build engineer doing a shared install, edit this script and set the variable "install_type" to "DLSshared"
#     this installs Buckminster Director into /dls_sw/apps/, then adds a pointer to it in the Modules system
# (2) a Diamond Light Source developer doing a private install, edit this script and set the variable "install_type" to "DLSprivate", and the variable "install_dir" as you want
#     this installs Buckminster Director into a designated directory, and sets the http proxy to the RAL proxy
# (3) a non-Diamond Light Source developer doing a private install, edit this script and set the variable "install_type" to "other", and the variable "install_dir" as you want
#     this installs Buckminster Director into a designated directory. you may need to set an http proxy definition in the script below

# The install is described in Appendix A of the "Bucky Book" (see Documentation link on http://www.eclipse.org/buckminster/)

# note that the director does not have a version number, so we just use the install date instead
#
# pre-requisites:
#    download director_latest.zip from http://www.eclipse.org/buckminster/downloads.html

set -o nounset  # variables must exist
set -o errexit  # exit on any error
set -o xtrace  # trace what the script does

install () {

    today=$(date +"%Y-%m-%d")

    ###############################################
    # <-- start of variables you may need to change

    # install type
    install_type=DLSshared
    #install_type=DLSprivate
    #install_type=other

    # zip and unzip locations
    zip_file=~/director_latest.zip
    unzip_dir=~/director_${today}_tmp

    # install location
    if [[ "${install_type}" != "DLSshared" ]]; then
        install_dir=~/director_${today}
    fi

    # end of variables you may need to change -->
    #############################################

    # install location for Diamond shared
    if [[ "${install_type}" == "DLSshared" ]]; then
        install_dir=/dls_sw/apps/director/${today}
        modules_dir=/dls_sw/apps/Modules/modulefiles/director
    fi

    #==========================================================
    # unzip the distribution
    rm -rf ${unzip_dir}
    unzip -q ${zip_file} -d ${unzip_dir}

    #==========================================================
    # set up the proxy as required at Diamond
    mkdir -p ${unzip_dir}/director/configuration/.settings/
    if [[ ${install_type} == DLS* ]]; then
        cat > ${unzip_dir}/director/configuration/.settings/org.eclipse.core.net.prefs <<'END_OF_CONFIG'
eclipse.preferences.version=1
nonProxiedHosts=*.diamond.ac.uk|localhost|127.0.0.1
org.eclipse.core.net.hasMigrated=true
proxyData/HTTP/hasAuth=false
proxyData/HTTP/host=wwwcache.rl.ac.uk
proxyData/HTTP/port=8080
proxyData/HTTPS/hasAuth=false
proxyData/HTTPS/host=wwwcache.rl.ac.uk
proxyData/HTTPS/port=8080
systemProxiesEnabled=false
END_OF_CONFIG
    fi

    #==========================================================
    # copy the install to its final location
    umask 0002
    rm -rf ${install_dir}
    cp --recursive --preserve=mode,timestamps ${unzip_dir}/director/ ${install_dir}/

    #==========================================================
    # add a new entry to the Modules system for the new version (but don't yet make it the default)
    if [[ "${install_type}" == "DLSshared" ]]; then
        rm -f ${modules_dir}/${today}
        cat > ${modules_dir}/${today} <<END_OF_MODULE_FILE
#%Module1.0
##
## Eclipse Buckminster Director configuration
##
proc ModulesHelp { } {
    global version
    puts stderr "\tSets the Eclipse Buckminster Director for use"
}

module-whatis "Sets the Eclipse Buckminster Director environment"

prepend-path PATH ${install_dir}

END_OF_MODULE_FILE
    fi

    #==========================================================
    # update the Modules system to point to the new version
    if [[ "${install_type}" == "DLSshared" ]]; then
        cd ${modules_dir}
        rm -f current
        ln -s ${today} current
    fi

    #==========================================================
    # test we can run it ok
    ${install_dir}/director -help

}

install

