# perform a Buckminster materialize in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/write.cquery_branches_file.sh

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

    if [ -z "${pewma_py}" ]; then
        echo "$""pewma_py not set, so terminating"
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

    # set materialize_properties_base, materialize_properties_extra, materialize_skip_list
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

    if [[ "${materialize_dawnsci_from_DawnScience}" == "true" ]]; then
        export materialize_properties_extra="${materialize_properties_extra} -Ddawnsci.github.organization=DawnScience"
    fi

    if [[ "${materialize_skip_list}" == "none" || -z "${materialize_skip_list+arbitrary}" ]]; then
        export materialize_skip_list_property=
    else
        export materialize_skip_list_property="-Dmaterialize_skip_list=${materialize_skip_list}"
    fi

    ###
    ### Materialize the workspace (type will be one of Fresh/Materialize/Recreate/Skip)
    ###     Fresh - discard existing workspace(_git)/, run materialize
    ###     extra-materialize - use existing workspace(_git)/, run materialize (if no workspace, do Fresh)
    ###     Recreate - clean/reset/pull existing workspace_git/, discard workspace/, run materialize
    ###     Skip - use existing workspace(_git)/ unchanged
    ### Note: the "extra-materialize" option is not shown in the Jenkins UI, it's just used internally
    ###       (e.g. to materialize squish tests on top of an existing workspace)
    ###

    export materialize_type=$(echo ${materialize_type:-fresh} | tr '[:upper:]' '[:lower:]')

    # translate the long materialize_type text to something shorter, for display
    if [[ "${materialize_type}" == *extra-materialize* ]]; then
       export materialize_type=extra-materialize
    elif [[ "${materialize_type}" == *recreate* ]]; then
       export materialize_type=recreate
    elif [[ "${materialize_type}" == *skip* ]]; then
       export materialize_type=skip
    elif [[ "${materialize_type}" == *fresh* ]]; then
       export materialize_type=fresh
    else
        echo "Unrecognised value $""{materialize_type}=${materialize_type}, so terminating"
        return 100
    fi

    # if there's nothing much there already, we have to do a fresh materialize, even if update was requested
    if [[ "${materialize_type}" == "extra-materialize" ]]; then
        if [[ ! -d "${materialize_workspace_path}_git" ]]; then
            echo "Resetting materialize_type from \"${materialize_type}\" to \"fresh\", since no existing workspace_git exists"
            export materialize_type=fresh
        elif [[ ! -d "${materialize_workspace_path}/.metadata" ]]; then
            echo "Resetting materialize_type from \"${materialize_type}\" to \"fresh\", since no existing workspace exists"
            export materialize_type=fresh
        fi
    fi

    if [[ "${materialize_type}" == "fresh" || "${materialize_type}" == "extra-materialize" || "${materialize_type}" == "recreate" ]]; then
        if [ -z "${materialize_components}" ]; then
            echo "$""materialize_components not set, so terminating"
            return 100
        fi
    fi

    set -x  # Turn on xtrace

    # from the CQuery, extract the standard branch names for whatever we are about to materialize
    write_cquery_branches_file_function

    if [[ "${materialize_type}" == "fresh" || "${materialize_type}" == "recreate" ]]; then
        rm -rf ${materialize_workspace_path}
        if [[ "${materialize_type}" == "fresh" ]]; then
            rm -rf ${materialize_workspace_path}_git
        fi
    fi

    # source the scripts that identify_changes_to_test_function.py possibly wrote
    #   notify_to_gerrit_at_start.sh         defines function pre_materialize_function_stage1_gerrit_job_started
    #   gerrit_pre.materialize.function.sh   defines function pre_materialize_function_stage2_gerrit
    #   gerrit_post.materialize.function.sh  defines function post_materialize_function_gerrit
    # (this just defines the functions, not runs them; they are run below)

    for generated_script in notify_to_gerrit_at_start.sh gerrit_pre.materialize.function.sh gerrit_post.materialize.function.sh; do
        if [ -f "${WORKSPACE}/artifacts_to_archive/${generated_script}" ]; then
            echo "Sourcing artifacts_to_archive/${generated_script}"
            . ${WORKSPACE}/artifacts_to_archive/${generated_script}
        fi
    done

    # execute any stage 1 pre_materialize_functions (if defined)
    for fname in $(compgen -A function pre_materialize_function_stage1_); do
        echo "Executing: ${fname}"
        ${fname}
    done

    # For each git repo, clean it, update from the remote origin, and make sure it is checked out on the standard branch
    # Process multiple repositories in parallel (xargs spawns separate processes; fail if any of them fails)
    # If there are any problems with the repo, delete it, and do not re-clone (Buckminster, or the scripts generated by identify_changes_to_test.py, will clone it later)
    # This just gets the standard branches, and is run BEFORE the scripts generated by identify_changes_to_test.py
    if [[ "${materialize_type}" == "update" || "${materialize_type}" == "recreate" ]]; then
        if [[ -d "${materialize_workspace_path}_git" ]]; then
            existing_repo_count=$(find ${materialize_workspace_path}_git -mindepth 1 -maxdepth 1 -type d -name '*.git' | wc -l)
            if [[ "${existing_repo_count}" != "0" ]]; then
                echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Cleaning and Updating ${existing_repo_count} existing git clones ***\n"
                set +e  # Turn off errexit
                find ${materialize_workspace_path}_git -mindepth 1 -maxdepth 1 -type d -name '*.git' -print0 | sort --zero-terminated | xargs --null --no-run-if-empty -I % -L 1 --max-procs 20 -n 1 bash -c 'update_single_git_repo_function "$@"' _
                RETVAL=$?
                set -e  # Restore errexit
                if [[ "${RETVAL}" != "0" ]]; then
                    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` update_single_git_repo_function failed for some repo(s); abandoning ***\n"
                    echo 'append-build-description: Failure updating existing repos (probable network issue)'
                    return ${RETVAL}
                fi
            fi
        fi
    fi

    # execute any stage 2 pre_materialize_functions (if defined)
    for fname in $(compgen -A function pre_materialize_function_stage2_); do
        echo "Executing: ${fname}"
        ${fname}
    done

    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` materialize_type=${materialize_type} ***\n"

    if [[ "${materialize_type}" == "fresh" || "${materialize_type}" == "extra-materialize" || "${materialize_type}" == "recreate" ]]; then
        rm -rf $(dirname ${materialize_workspace_path})/buckminster-runtime-areas
        if [[ "${materialize_type}" == "fresh" || "${materialize_type}" == "recreate" ]]; then
            # if fresh was specified, we have already deleted any previous workspace and workspace_git
            # but we need to say --recreate and not --delete, in case the pre_materialize_functions cloned and set up a repository (e.g. for Gerrit tests)
            workspace_delete_option=--recreate
        fi
        # materialize_properties_special is specified when the Jenkins job starts (normally empty)
        if [[ -z "${materialize_cquery}" ]]; then
            ${pewma_py} ${log_level_option} ${workspace_delete_option} -w ${materialize_workspace_path} ${keyring_option} ${materialize_location_option} ${materialize_properties_base} ${materialize_properties_extra} ${materialize_properties_special} ${materialize_skip_list_property} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} materialize ${materialize_components} ${materialize_category} ${materialize_version} || return 1
        else
            ${pewma_py} ${log_level_option} ${workspace_delete_option} -w ${materialize_workspace_path} ${keyring_option} ${materialize_location_option} ${materialize_properties_base} ${materialize_properties_extra} ${materialize_properties_special} ${materialize_skip_list_property} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} materialize ${materialize_components} ${materialize_cquery} || return 1
        fi
    fi

    # execute any post_materialize_functions (if defined)
    for fname in $(compgen -A function post_materialize_function_); do
        echo "Executing: ${fname}"
        ${fname}
    done

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

