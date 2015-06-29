# clean up old artifacts previously published for "module load"

#------------------------------------#
#------------------------------------#

dawn_cleanup_moduleload_function () {

    # Save xtrace state (1=was not set, 0=was set)
    if [[ $- = *x* ]]; then
        oldxtrace=0
    else
        oldxtrace=1
    fi
    set +x  # Turn off xtrace

    # Save errexit state (1=was not set, 0=was set)
    if [[ $- = *e* ]]; then
        olderrexit=0
    else
        olderrexit=1
    fi
    set -e  # Turn on errexit

    ###
    ### Determine options
    ###

    export cleanup_type=$(echo ${cleanup_type:-notset} | tr '[:upper:]' '[:lower:]')

    # translate the long cleanup_type text to something shorter, for display
    if [[ "${cleanup_type}" == *snapshot* ]]; then
       export cleanup_type=snapshot
    elif [[ "${cleanup_type}" == *beta* ]]; then
       export cleanup_type=beta
    elif [[ "${cleanup_type}" == *stable* ]]; then
       export cleanup_type=stable
    else
        echo "Unrecognised value $""{cleanup_type}=${cleanup_type}, so terminating"
        return 100
    fi

    export cleanup_module_load=$(echo ${cleanup_module_load:-true} | tr '[:upper:]' '[:lower:]')
    export cleanup_linux32=$(echo ${cleanup_linux32:-true} | tr '[:upper:]' '[:lower:]')
    export cleanup_linux64=$(echo ${cleanup_linux64:-true} | tr '[:upper:]' '[:lower:]')
    export cleanup_windows32=$(echo ${cleanup_windows32:-true} | tr '[:upper:]' '[:lower:]')
    export cleanup_windows64=$(echo ${cleanup_windows64:-true} | tr '[:upper:]' '[:lower:]')
    export cleanup_mac64=$(echo ${cleanup_mac64:-true} | tr '[:upper:]' '[:lower:]')

    ###
    ### Cleanup as requested
    ###

    if [[ -n "${nice_setting_common:-}" ]]; then
        chmod="nice -n ${nice_setting_common} chmod"
        rm="nice -n ${nice_setting_common} rm"
    else
        chmod="chmod"
        rm="rm"
    fi

    set -x  # Turn on xtrace

    if [[ "${cleanup_module_load}" == "true" ]]; then
        rm -fv ${WORKSPACE}/cleanup_*_script
        for platform in linux32 linux64 windows32 windows64 mac64; do
            cleanup_platform__indirect="cleanup_${platform}"
            if [[ "${!cleanup_platform__indirect}" == "true" ]]; then
                echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S"` Cleaning up module load for ${platform} ***\n"
                export publish_module_load_directory_for_type=${publish_module_load_directory_parent}/builds-${cleanup_type}
                export platform
                python ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_cleanup_moduleload.py > ${WORKSPACE}/cleanup_${platform}_script
                . ${WORKSPACE}/cleanup_${platform}_script
            fi
        done
    else
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S"` Skipping cleanup of module load ***\n"
    fi

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

