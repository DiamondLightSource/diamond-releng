#!/bin/bash
###
### Installs the Eclipse Buckminster Headless application.
### READ AND UNDERSTAND WHAT THIS DOES BEFORE RUNNING!
###

# If you are:
# (1) a Diamond Light Source build engineer doing a shared install, edit this script and set the variable "install_type" to "DLSshared"
#     this installs Buckminster Headless into /dls_sw/apps/, then adds a pointer to it in the Modules system
#     Note that the install needs to be done twice, once for 32 bit and once for 64 bit Linux, and the installs need to be done on the same date (due to simple-minded modulefile)
# (2) a Diamond Light Source developer doing a private install, edit this script and set the variable "install_type" to "DLSprivate", and the variable "install_dir" as you want
#     this installs Buckminster Headless into a designated directory, and sets the http proxy to the RAL proxy
# (3) a non-Diamond Light Source developer doing a private install, edit this script and set the variable "install_type" to "other", and the variable "install_dir" as you want
#     this installs Buckminster Headless into a designated directory. you may need to set an http proxy definition in the script below

# The install is described in Appendix A of the "Bucky Book" (see Documentation link on http://www.eclipse.org/buckminster/)

set -o nounset  # variables must exist
set -o errexit  # exit on any error
set -o xtrace  # trace what the script does

install () {

    ###############################################
    # <-- start of variables you may need to change

    # install type
    #install_type=DLSshared
    install_type=DLSprivate
    #install_type=other
    version=4.3

    # install location
    if [[ "${install_type}" != "DLSshared" ]]; then
        install_dir=~/buckminster_${version}
    fi

    # location of director
    if [[ ${install_type} != DLS* ]]; then
        director_command=director
    fi

    # end of variables you may need to change -->
    #############################################

    # install location for Diamond shared
    if [[ "${install_type}" == "DLSshared" ]]; then
        today=$(date +"%Y-%m-%d")
        uname=`uname -m`
        if [ "${uname}" == "i686" ]; then
            arch=32
        elif [ "${uname}" == "x86_64" ]; then
            arch=64
        else
            echo "Could not determine current machine architecture - \"uname -m\" returned \"${uname}\" - exiting"
            return 1
        fi
        install_parent=/dls_sw/apps/buckminster
        install_suffix=${version}-${today}
        install_dir=${install_parent}/${arch}/${install_suffix}
        modules_dir=/dls_sw/apps/Modules/modulefiles/buckminster
    fi

    # location of director for Diamond
    if [[ ${install_type} == DLS* ]]; then
        module load director
        director_command=director
    fi

    repository_buckminster=http://download.eclipse.org/tools/buckminster/headless-${version}
    repository_cloudsmith=http://download.cloudsmith.com/buckminster/external-${version}

    #==========================================================
    # install the base headless product
    umask 0002
    rm -rf ${install_dir}
    director -repository ${repository_buckminster} -destination ${install_dir} -profile Buckminster -installIU org.eclipse.buckminster.cmdline.product

    #==========================================================
    # ensure that Buckminster is only run under Java 7
    cat << EOF >> ${install_dir}/eclipse.ini
-vmargs
-Dfile.encoding=UTF-8
-Dosgi.requiredJavaVersion=1.7
EOF

    #==========================================================
    # set up the proxy as required at Diamond
    mkdir -p ${install_dir}/configuration/.settings/
    if [[ ${install_type} == DLS* ]]; then
        cat > ${install_dir}/configuration/.settings/org.eclipse.core.net.prefs <<'END_OF_CONFIG'
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
    # add a new entry to the Modules system for the new version (but don't yet make it the default)
    if [[ "${install_type}" == "DLSshared" ]]; then
        rm -f ${modules_dir}/${version}-${today}
        cat > ${modules_dir}/${version}-${today} <<END_OF_MODULE_FILE
#%Module1.0
##
## Eclipse Buckminster Headless
##
proc ModulesHelp { } {
    global version
    puts stderr "\tSets Eclipse Buckminster Headless for use"
}

module-whatis "Sets the Eclipse Buckminster Headless environment"

set mach \$tcl_platform(machine)

if {[string  compare  \$mach  "x86_64"] == 0} {
    append-path PATH ${install_parent}/64/${install_suffix}
} else {
    append-path PATH ${install_parent}/32/${install_suffix}
}

END_OF_MODULE_FILE
    fi

    #==========================================================
    # install additional features into the just-installed Buckminster
    # org.eclipse.buckminster.core.headless.feature : The Core functionality — this feature is required if you want to do anything with Buckminster except installing additional features.
    # org.eclipse.buckminster.pde.headless.feature : Headless PDE and JDT support. Required if you are working with Java based components.
    # org.eclipse.buckminster.git.headless.feature : Git
    # org.eclipse.buckminster.subclipse.headless.feature : Subclipse

    buckminster_command=${install_dir}/buckminster
    ${buckminster_command} install ${repository_buckminster} org.eclipse.buckminster.core.headless.feature
    ${buckminster_command} install ${repository_buckminster} org.eclipse.buckminster.pde.headless.feature
    ${buckminster_command} install ${repository_buckminster} org.eclipse.buckminster.git.headless.feature
    ${buckminster_command} install ${repository_cloudsmith} org.eclipse.buckminster.subclipse.headless.feature

    #==========================================================
    # mark the buckminster install read-only so that it can be shared by multiple concurrent users
    chmod -R a-w ${install_dir}

    #==========================================================
    # update the Modules system to point to the new version
    if [[ "${install_type}" == "DLSshared" ]]; then
        cd ${modules_dir}
        rm -f ${version}
        ln -s ${version}-${today} ${version}
    fi

    #==========================================================
    # report the version that we installed
    grep buckminster ${install_dir}/artifacts.xml | sort

    #==========================================================
    # test we can run it ok
    ${buckminster_command} lscmds

}

install

