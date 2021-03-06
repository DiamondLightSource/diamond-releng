#!/bin/bash
###
### Installs the Eclipse Buckminster Headless application. Pre-requisites: none
### READ AND UNDERSTAND WHAT THIS DOES BEFORE RUNNING!
###
### Note: this script supercedes the earlier (install-director-headless.sh / install-buckminster-headless.sh) combination
###

# This script supports two different modes of install:
# (1) [DEFAULT] a developer doing a private install. to run,
#         export buckminster_install_dir=/path/to/install/dir  # optional, default is ~/bin/buckminster-${buckminster_version}-${datetime})
#         ./buckminster_headless_install.sh
#     this installs Buckminster Headless into the designated directory. you may need to set $http_proxy before running
# (2) a Diamond Light Source build engineer doing a shared install. to run,
#         export buckminster_install_type=DLSshared
#         ./buckminster_headless_install.sh
#     this installs Buckminster Headless (for 64-bit only) into /dls_sw/apps/, then adds a pointer to it in the Modules system

# The install is described in Appendix A of the "Bucky Book" (see Documentation link on http://www.eclipse.org/buckminster/)

install_buckminster () {

    set -o errexit  # exit on any error
    set -o xtrace   # trace what the script does

    datetime=$(date +"%Y%m%d-%H%M")

    ###############################################
    # <-- start of variables you may need to change

    # buckminster version (same as an Eclipse version)
    if [[ -z "${buckminster_version}" ]]; then
        buckminster_version=4.5
    fi

    # download location; either "standard" (server visible both inside and outside DLS, a local mirror of part of eclipse.org)
    #                        or "eclipse"  (from eclipse.org, or possibly a mirror selected by eclipse.org)
    if [[ -z "${download_location}" ]]; then
        download_location=standard
    fi

    # install type
    if [[ -z "${buckminster_install_type}" ]]; then
        buckminster_install_type=private
        #buckminster_install_type=DLSshared
    fi

    # install location
    if [[ "${buckminster_install_type}" != "DLSshared" ]]; then
        if [[ -z "${buckminster_install_dir}" ]]; then
            buckminster_install_dir=~/bin/buckminster-${buckminster_version}-${datetime}
        fi
    fi

    # end of variables you may need to change -->
    #############################################

    # install location for Diamond shared
    if [[ "${buckminster_install_type}" == "DLSshared" ]]; then
        uname=`uname -m`
        if [ "${uname}" != "x86_64" ]; then
            echo "Unexpected current machine architecture - \"uname -m\" returned \"${uname}\" (not \"x86_64\" as expected - exiting"
            return 1
        fi
        install_parent=/dls_sw/apps/buckminster
        install_suffix=${buckminster_version}-${datetime}
        buckminster_install_dir=${install_parent}/${install_suffix}
        modules_dir=/dls_sw/apps/Modules/modulefiles/buckminster
    fi

    # create a temporary directory name: %/ is used to remove any trailing slash
    buckminster_install_dir_temp=${buckminster_install_dir%/}_install-in-progress

    if [[ "${download_location}" == "standard" ]]; then
        director_download="https://alfred.diamond.ac.uk/sites/download.eclipse.org/tools/buckminster/products/director_latest.zip"
        repository_buckminster=https://alfred.diamond.ac.uk/sites/download.eclipse.org/tools/buckminster/headless-${buckminster_version}
        vmarg_mirror_option=' -vmargs -Declipse.p2.mirrors=false'
    else
        director_download="http://download.eclipse.org/tools/buckminster/products/director_latest.zip"
        repository_buckminster=http://download.eclipse.org/tools/buckminster/headless-${buckminster_version}
        vmarg_mirror_option=
    fi

    #==========================================================
    # report what we are doing
    echo "Installing Buckminster headless ${buckminster_version} to ${buckminster_install_dir_temp}"

    set -o nounset  # variables must exist

    #==========================================================
    for dir in ${buckminster_install_dir_temp} ${buckminster_install_dir}; do
        if [[ -d "${dir}" ]]; then
            echo "Deleting existing ${dir}"
            rm -rf ${dir}
        fi
    done
    umask 0002

    #==========================================================
    # install the director
    director_zip_file=${buckminster_install_dir_temp}/director_latest.zip
    director_unzip_dir=${buckminster_install_dir_temp}/director_${datetime}
    mkdir -pv $(dirname ${director_zip_file})
    set -x  # Turn on xtrace
    if tty -s; then
        # standard (verbose) output at the terminal
        wget --timeout=180 --tries=2 --no-cache -O ${director_zip_file} "${director_download}"
    else
        # non-verbose output in a batch job
        set +e  # Turn off errexit
        wget --timeout=180 --tries=2 --no-cache -nv -O ${director_zip_file} "${director_download}"
        RETVAL=$?
        set -e  # Turn errexit on
        if [ "${RETVAL}" != "0" ]; then
            if [[ "${JENKINS_URL}" = *diamond.ac.uk* ]]; then
                # running under Jenkins at DLS, so write text to log so that job build description is set 
                echo "append-build-description: Failure on wget from $(echo ${director_download} | awk -F/ '{print $3}') (${director_download_location}) (probable network issue)"
            fi
            return ${RETVAL}
        fi
    fi
    set +x  # Turn off xtrace

    rm -rf ${director_unzip_dir}
    unzip -q ${director_zip_file} -d ${director_unzip_dir}

    #==========================================================
    # install the base headless product, then delete the director
    ${director_unzip_dir}/director/director -repository ${repository_buckminster} -destination ${buckminster_install_dir_temp} -profile Buckminster -installIU org.eclipse.buckminster.cmdline.product${vmarg_mirror_option}
    echo "finished installing org.eclipse.buckminster.cmdline.product"
    rm -rf ${director_unzip_dir}
    rm -f ${director_zip_file}

    #==========================================================
    # ensure that Buckminster is only run under Java 8 or higher
    cat << EOF >> ${buckminster_install_dir_temp}/eclipse.ini
-vmargs
-Dfile.encoding=UTF-8
-Dosgi.requiredJavaVersion=1.8
EOF

    #==========================================================
    # install additional features into the just-installed Buckminster
    # org.eclipse.buckminster.core.headless.feature : The Core functionality — this feature is required if you want to do anything with Buckminster except installing additional features.
    # org.eclipse.buckminster.pde.headless.feature : Headless PDE and JDT support. Required if you are working with Java based components.
    # org.eclipse.buckminster.git.headless.feature : Git
    # org.eclipse.buckminster.maven.headless.feature : Maven support

    buckminster_command_temp=${buckminster_install_dir_temp}/buckminster
    for feature in org.eclipse.buckminster.core.headless.feature org.eclipse.buckminster.pde.headless.feature org.eclipse.buckminster.git.headless.feature org.eclipse.buckminster.maven.headless.feature; do
        echo "issuing --> ${buckminster_command_temp} install ${repository_buckminster} ${feature}${vmarg_mirror_option}"
        ${buckminster_command_temp} install ${repository_buckminster} ${feature}${vmarg_mirror_option}
        echo "finished installing ${feature}"
    done

    #==========================================================
    mv -v ${buckminster_install_dir_temp}/ ${buckminster_install_dir%/}/
    export buckminster_command=${buckminster_install_dir%/}/buckminster

    #==========================================================
    #==========================================================
    # add a new entry to the Modules system for the new version (but don't yet make it the default)
    if [[ "${buckminster_install_type}" == "DLSshared" ]]; then
        rm -f ${modules_dir}/${buckminster_version}-${datetime}
        cat > ${modules_dir}/${buckminster_version}-${datetime} <<END_OF_MODULE_FILE
#%Module1.0
##
## Eclipse Buckminster Headless
##
proc ModulesHelp { } {
    global version
    puts stderr "\tSets Eclipse Buckminster Headless for use"
}

module-whatis "Sets the Eclipse Buckminster Headless environment"

append-path PATH ${install_parent}/${install_suffix}

END_OF_MODULE_FILE

        #==========================================================
        # mark the buckminster install read-only so that it can be shared by multiple concurrent users
        chmod -R a-w ${buckminster_install_dir}

        #==========================================================
        # update the Modules system to point to the new version
        #cd ${modules_dir}
        #rm -f ${buckminster_version}
        #ln -s ${buckminster_version}-${datetime} ${buckminster_version}
    fi

    #==========================================================
    # report what we have done (skip if not at the terminal)
    set +o xtrace
    if tty -s; then
        echo
        echo "======================================================="
        echo "Install completed. To use Buckminster headless, either:"
        echo "(1) add \"${buckminster_install_dir%/}\" to your $""PATH"
        echo "(2) issue \"$""{buckminster_command}\" (expands to \"${buckminster_command}\")"
    fi

    if [[ "${buckminster_install_type}" == "DLSshared" ]]; then
        echo
        echo "======================================================="
        echo "To make this the default version loaded by \"module load buckminster\", do the following:"
        echo "    cd ${modules_dir}"
        echo "    rm ${buckminster_version}"
        echo "    ln -s ${buckminster_version}-${datetime} ${buckminster_version}"
    fi
    echo

    set +o errexit  # reset back
    set +o xtrace   # reset back

}

install_buckminster

