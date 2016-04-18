# perform a Buckminster build in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

build_function () {

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
    ### Build the workspace (type will be one of clean/incremental/skip)
    ###

    export workspace_build_type=$(echo ${workspace_build_type:-incremental} | tr '[:upper:]' '[:lower:]')

    # translate the long workspace_build_type text to something shorter, for display
    if [[ "${workspace_build_type}" == *clean* ]]; then
       export workspace_build_type=clean
    elif [[ "${workspace_build_type}" == *incremental* ]]; then
       export workspace_build_type=incremental
    elif [[ "${workspace_build_type}" == *skip* ]]; then
       export workspace_build_type=skip
    else
        echo "Unrecognised value $""{workspace_build_type}=${workspace_build_type}, so terminating"
        return 100
    fi

    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` workspace_build_type=${workspace_build_type} ***\n"

    set -x  # Turn on xtrace

    if [[ "${workspace_build_type}" == *clean* ]]; then
        ${pewma_py} ${log_level_option} ${build_options_extra} -w ${materialize_workspace_path} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} clean || return 1
    fi

    if [[ "${workspace_build_type}" != *skip* ]]; then
        set +e  # Turn off errexit. If there is a compile error, we want to handle it ourselves, rather than exiting immediately
        ${pewma_py} ${log_level_option} ${build_options_extra} -w ${materialize_workspace_path} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} buildthorough
        retcode=$?
        if [[ "${build_attempt_twice:-false}" == "true" ]]; then
            # Due to long dependency chains, the first GDA build fails with "The project cannot be built until its prerequisite is built",
            # and needs to be followed by an incremental build to complete the build.
            if [[ "${retcode}" != "0" ]]; then
                ${pewma_py} ${log_level_option} ${build_options_extra} --suppress-compile-warnings -w ${materialize_workspace_path} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} buildinc
                retcode=$?
            fi
        fi
        $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
        if [[ "${retcode}" != "0" ]]; then
            if [[ "${do_not_fail_on_compile_errors:-false}" != "true" ]]; then
                echo 'append-build-description: Failure - compile errors'
                return 1
            fi
            echo -e "\n*** Compile failed, but continuing test job, since \${do_not_fail_on_compile_errors}=true ***\n"
        fi
    fi

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

