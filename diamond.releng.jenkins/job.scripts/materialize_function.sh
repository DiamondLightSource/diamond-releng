# perform a Buckminster materialize in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

materialize_function () {

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
    ### Setup environment
    ###

    if [ -z "${dawn_py}" ]; then
        echo "$""dawn_py not set, so terminating"
        return 100
    fi

    # the eclipse keyring is used to hold the subversion credentials, if required
    #    do not create the --keyring option string if keyring_location is "none" or is set to null, or is not set
    #    create the --keyring option string if keyring_location is set to "default"
    #    create the --keyring option string if keyring_location is set
    # if a keyring is provided, we copy it and use the copy, to avoid corruption problems that have been observed

    if [[ "${keyring_location}" == "none" || -z "${keyring_location-arbitrary}" || -z "${keyring_location+arbitrary}" ]]; then
        keyring_location=
    elif [[ "${keyring_location}" == "default" ]]; then
        keyring_location=/home/dlshudson/.eclipse-keyring-backup
    elif [[ "${keyring_location+arbitrary}" ]]; then
        :
    else
        echo 'Error in logic determining "keyring_location"'
        return 100
    fi
    if [[ -n "${keyring_location}" ]]; then
      set -x  # Turn on xtrace
      cp -fpv ${keyring_location} ${WORKSPACE}/.eclipse-keyring
      keyring_option="--keyring=${WORKSPACE}/.eclipse-keyring"
      set +x  # Turn off xtrace
    else
      keyring_option=
    fi

    # set materialize_properties_base and materialize_properties_extra
    if [[ "${materialize_properties_base}" == "none" || -z "${materialize_properties_base+arbitrary}" ]]; then
        export materialize_properties_base=
    else
        export materialize_properties_base
    fi
    if [[ "${materialize_properties_extra}" == "none" || -z "${materialize_properties_extra+arbitrary}" ]]; then
        export materialize_properties_extra=
    else
        export materialize_properties_extra
    fi

    ###
    ### Materialize the workspace (type will be one of Update/Fresh/Redo/Skip)
    ###     Update - use existing workspace, update repositories (if no workspace, do a new materialize)
    ###     Fresh - discard any existing workspace, do a new materialize
    ###     Redo - use existing workspace, rerun materialize (if no workspace, do a new materialize) DOES NOT DO AN UPDATE
    ###     Skip - use existing workspace unchanged    
    ###

    export materialize_type=$(echo ${materialize_type:-fresh} | tr '[:upper:]' '[:lower:]')

    # translate the long materialize_type text to something shorter, for display
    if [[ "${materialize_type}" == *update* ]]; then
       export materialize_type=update
    elif [[ "${materialize_type}" == *fresh* ]]; then
       export materialize_type=fresh
    elif [[ "${materialize_type}" == *redo* ]]; then
       export materialize_type=redo
    elif [[ "${materialize_type}" == *skip* ]]; then
       export materialize_type=skip
    else
        echo "Unrecognised value $""{materialize_type}=${materialize_type}, so terminating"
        return 100
    fi

    # if there is no existing populated workspace, then do a fresh materialize, even if update was requested
    if [[ "${materialize_type}" != "skip" ]]; then
        if [[ ! -d "${materialize_workspace_path}/.metadata" ]]; then
            if [[ "${materialize_type}" != "fresh" ]]; then
                echo "Resetting materialize_type from \"${materialize_type}\" to \"fresh\", since no existing workspace exists"
                export materialize_type=fresh
            fi
        fi
    fi
    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S"` materialize_type=${materialize_type} ***\n"

    if [[ ( "${materialize_type}" == "fresh" ) || ( "${materialize_type}" == "redo" ) ]]; then
        if [ -z "${materialize_component}" ]; then
            echo "$""materialize_component not set, so terminating"
            return 100
        fi
    fi

    if [[ "${materialize_type}" == "fresh" ]]; then
        workspace_delete_option=--delete
    else
        workspace_delete_option=
    fi

    set -x  # Turn on xtrace

    rm -f ${WORKSPACE}/head_commits.txt

    if [[ ( "${materialize_type}" == "fresh" ) || ( "${materialize_type}" == "redo" ) ]]; then
        # delete any existing workspace, and initialize a new workspace
        rm -rf $(dirname ${materialize_workspace_path})/buckminster-runtime-areas
        if [[ -z "${materialize_cquery}" ]]; then
            ${dawn_py} ${log_level_option} ${workspace_delete_option} --workspace ${materialize_workspace_path} ${keyring_option} ${materialize_location_option} ${materialize_properties_base} ${materialize_properties_extra} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} materialize ${materialize_component} ${materialize_category} ${materialize_version} || return 1
        else
            ${dawn_py} ${log_level_option} ${workspace_delete_option} --workspace ${materialize_workspace_path} ${keyring_option} ${materialize_location_option} ${materialize_properties_base} ${materialize_properties_extra} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} materialize ${materialize_component} ${materialize_cquery} || return 1
        fi

    elif [[ "${materialize_type}" == "update" ]]; then
        # update whatever is in the existing workspace
        ${dawn_py} ${log_level_option} -w ${materialize_workspace_path} git pull
    fi
    if [[ "${materialize_type}" != *skip* ]]; then
      ${dawn_py} -w ${materialize_workspace_path} git log -1
    fi

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

