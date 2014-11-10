# set the environment at the start of a Jenkins "Execute shell" build step
# takes as optional parameter(s), the name(s) of properties file(s) to include

set +x  # Turn off xtrace

# Save errexit state (1=was not set, 0=was set)
if [[ $- = *e* ]]; then
    olderrexit=0
else
    olderrexit=1
fi
set -e  # Turn on errexit

# Save allexport state (1=was not set, 0=was set)
if [[ $- = *a* ]]; then
    oldallexport=0
else
    oldallexport=1
fi

#------------------------------------#
#------------------------------------#

set_environment_step () {

    ###
    ### Set environment variables
    ###

    # Get real path to this script (from http://stackoverflow.com/questions/59895/)
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    job_scripts_dir="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    properties_dir=$(readlink -e "${job_scripts_dir}/../properties")

    # Source properties files to set environment variables
    set -a  # Turn on allexport
    echo "running \". ${properties_dir}/Common-environment-variables.properties\""
    . ${properties_dir}/Common-environment-variables.properties
    for propfile in "$@"; do
        if [ -f "${properties_dir}/${propfile}" ]; then
            echo "running \". ${properties_dir}/${propfile}\""
            . ${properties_dir}/${propfile}
        else
            echo "Parameter error: ${properties_dir}/${propfile} does not exist"
            return 100
        fi
    done
    if [ -f "${WORKSPACE}/job-specific-environment-variables.properties" ]; then
         # if required, job-specific-environment-variables.properties should be written in a previous build step
         echo "running \". ${WORKSPACE}/job-specific-environment-variables.properties\""
         . ${WORKSPACE}/job-specific-environment-variables.properties
    fi

    ###
    ### Load modules
    ###
    
    if [[ "${MODULEPATH}" == */dls_sw/apps/Modules/modulefiles* ]]; then

        # do not issue "module load xxx" if module_load_xxx_version is not set, or is set to null, or is set to "none"
        # issue "module load xxx" if module_load_xxx_version is set to "default"
        # issue "module load xxx/version" if module_load_xxx_version is set

        if [[ "${module_load_java_version}" == "none" || -z "${module_load_java_version-arbitrary}" || -z "${module_load_java_version+arbitrary}" ]]; then
            echo 'skipping "module load java"'
        elif [[ "${module_load_java_version}" == "default" ]]; then
            echo "issuing \"module load java\""
            module load java
        elif [[ "${module_load_java_version+arbitrary}" ]]; then
            echo "issuing \"module load java/${module_load_java_version}\""
            module load java/${module_load_java_version}
        else
            echo 'Error in logic determining "module load java"'
            return 100
        fi

        if [[ "${module_load_buckminster_version}" == "none" || -z "${module_load_buckminster_version-arbitrary}" || -z "${module_load_buckminster_version+arbitrary}" ]]; then
            echo 'skipping "module load buckminster"'
        elif [[ "${module_load_buckminster_version}" == "default" ]]; then
            echo "issuing \"module load buckminster\""
            module load buckminster
        elif [[ "${module_load_buckminster_version+arbitrary}" ]]; then
            echo "issuing \"module load buckminster/${module_load_buckminster_version}\""
            module load buckminster/${module_load_buckminster_version}
        else
            echo 'Error in logic determining "module load buckminster"'
            return 100
        fi

        if [[ "${module_load_python_version}" == "none" || -z "${module_load_python_version-arbitrary}" || -z "${module_load_python_version+arbitrary}" ]]; then
            echo 'skipping "module load python"'
        elif [[ "${module_load_python_version}" == "default" ]]; then
            echo "issuing \"module load python\""
            module load python
        elif [[ "${module_load_python_version+arbitrary}" ]]; then
            echo "issuing \"module load python/${module_load_python_version}\""
            module load python/${module_load_python_version}
        else
            echo 'Error in logic determining "module load python"'
            return 100
        fi

    else
        echo "Diamond Modules system not available"
    fi

    # set path to dawn.py if it is not already set
    if [[ "${dawn_py_use_public_version:-}" == "true" ]]; then
        # download dawn.py from the public web site and use that
        dawn_py="${WORKSPACE}/dawn.py"
        rm -f ${dawn_py}
        set -x  # Turn on xtrace
        wget -nv -P ${WORKSPACE} http://www.opengda.org/buckminster/software/dawn.py
        chmod +x ${dawn_py}
        set +x  # Turn off xtrace
    elif [[ "${dawn_py_use_public_version:-false}" == "false" ]]; then
        if [[ -z "${dawn_py}" ]]; then
            dawn_py="/dls_sw/dasc/dawn.py"
        fi
    else
        echo "Unrecognised value of $""dawn_py_use_public_version=\"${dawn_py_use_public_version}\" - exiting"
        return 100
    fi
    if [[ -n "${nice_setting_common:-}" ]]; then
        dawn_py="nice -n ${nice_setting_common} ${dawn_py}"
    fi
    export dawn_py

    ###
    ### Setup environment
    ###

    # Jenkins sets BUILD_ID to YYYY-MM-DD_hh-mm-ss. We convert this to YYYYMMDD_HHMMSS
    if [ -z "${build_timestamp}" ]; then
        if [ "${#BUILD_ID}" == "19" ]; then
            export build_timestamp=${BUILD_ID:0:4}${BUILD_ID:5:2}${BUILD_ID:8:2}_${BUILD_ID:11:2}${BUILD_ID:14:2}${BUILD_ID:17:2}
        else
            export build_timestamp=$(date +"%Y%m%d_%H%M%S")
        fi
    fi
    # "touch" requires a timestamp in the form [[CC]YY]MMDDhhmm[.ss], so convert build_timestamp to CCYYMMDDhhmm.ss
    if [ "${#build_timestamp}" == "15" ]; then
        export touch_timestamp=${build_timestamp:0:8}${build_timestamp:9:4}.${build_timestamp:13:2}
    fi

    # log level (for Buckminster)
    if [ -z "${log_level}" ]; then
        export log_level_option=
    else
        export log_level_option="--log-level=${log_level}"
    fi

    # Workspace
    if [ -z "${materialize_workspace_name}" ]; then
        export materialize_workspace_name=materialize_workspace
    fi
    if [ -z "${materialize_workspace_path}" ]; then
        if [ -z "${WORKSPACE}" ]; then
            export materialize_workspace_path=`pwd`/${materialize_workspace_name}
        else
          export materialize_workspace_path=${WORKSPACE}/${materialize_workspace_name}
        fi
    else
        export materialize_workspace_path
    fi
    export materialize_workspace_name=$(basename ${materialize_workspace_path})
    export buckminster_root_prefix=$(dirname ${materialize_workspace_path})/create.product.root

    # set buckminster_osgi_areas to null if is "none"
    # set buckminster_osgi_areas to the default value, if it is set to "default", or is not set
    if [[ "${buckminster_osgi_areas}" == "none" ]]; then
        export buckminster_osgi_areas=
    elif [[ "${buckminster_osgi_areas}" == "default" || -z "${buckminster_osgi_areas+arbitrary}" ]]; then
        export buckminster_osgi_areas="-Josgi.configuration.area=$(dirname ${materialize_workspace_path})/buckminster-runtime-areas/configuration/ -Josgi.user.area=$(dirname ${materialize_workspace_path})/buckminster-runtime-areas/user/"
    elif [[ "${buckminster_osgi_areas+arbitrary}" ]]; then
        export buckminster_osgi_areas
    else
        echo 'Error in logic determining "buckminster_osgi_areas"'
        return 100
    fi

    # set buckminster_extra_vmargs to null if is "none"
    # set buckminster_extra_vmargs to the default value, if it is set to "default", or is not set
    if [[ "${buckminster_extra_vmargs}" == "none" ]]; then
        export buckminster_extra_vmargs=
    elif [[ "${buckminster_extra_vmargs}" == "default" || -z "${buckminster_extra_vmargs+arbitrary}" ]]; then
        export buckminster_extra_vmargs="-Jequinox.statechange.timeout=30000"
    elif [[ "${buckminster_extra_vmargs+arbitrary}" ]]; then
        export buckminster_extra_vmargs
    else
        echo 'Error in logic determining "buckminster_extra_vmargs"'
        return 100
    fi

    ###
    ### Report environment
    ###

    echo -e "\nRunning with java=$(which java 2> /dev/null) $""{JAVA_HOME}=${JAVA_HOME}";java -version
    echo -e "Running with python=$(which python 2> /dev/null)";python -V;echo "$""{PYTHONHOME}=${PYTHONHOME}";echo "$""{PYTHONPATH}=${PYTHONPATH}"
    echo -e "Running with git=$(which git 2> /dev/null)";git --version
    echo -e "Running with buckminster=$(which buckminster 2> /dev/null)\n"

}

#------------------------------------#
#------------------------------------#

set_environment_step $@

$([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
$([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
$([ "$oldallexport" == "0" ]) && set -a || true  # Turn allexport on if it was on at the top of this script
$([ "$oldallexport" == "1" ]) && set +a || true  # Turn allexport off if it was off at the top of this script

set -x  # Turn on xtrace
