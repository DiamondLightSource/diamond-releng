# Zip materialized workspace in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

zip_materialized_workspace_function () {

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
    ### Zip the materialize workspace
    ###

    if [[ -n "${nice_setting_common:-}" ]]; then
        zip="nice -n ${nice_setting_common} zip"
    else
        zip="zip"
    fi

    # zip materialize_workspace and materialize_workspace_git
    rm -fv ${WORKSPACE}/materialize_workspace.zip
    zip_materialized_workspace=$(echo ${zip_materialized_workspace:-false} | tr '[:upper:]' '[:lower:]')
    set -x  # Turn on xtrace
    if [[ "${zip_materialized_workspace}" == "true" ]]; then
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S UTC%z"` zipping materialized workspace ***\n"
        cd $(dirname ${materialize_workspace_path})
        zip -qr ${WORKSPACE}/materialized_workspace.zip ${materialize_workspace_name}
        zip -qr ${WORKSPACE}/materialized_workspace.zip ${materialize_workspace_name}_git -x "*/.git/*"
        if [ -n "${touch_timestamp}" ]; then
            touch -t ${touch_timestamp} ${WORKSPACE}/materialized_workspace.zip
        fi
    fi


    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

