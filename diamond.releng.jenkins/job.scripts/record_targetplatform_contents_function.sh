# record the target platform contents

#------------------------------------#
#------------------------------------#

record_targetplatform_contents_function () {

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
    ### Record target platform details - name and version
    ###

    cd ${materialize_workspace_path}/tp/
    features_recorded=0
    plugins_recorded=0
    echo "# List of target platform contents in ${materialize_workspace_path}/tp/"
    echo "# Written `date +"%a %d/%b/%Y %H:%M:%S"` in Jenkins ${BUILD_TAG} (${BUILD_URL})"

    # TODO - extract names and versions

    echo "# Features reported on = ${features_recorded}"
    echo "# Plugins reported on = ${plugins_recorded}"

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

