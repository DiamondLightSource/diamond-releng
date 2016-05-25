# various functions to get the details of what was materialized, for subsequent saving

#-----------------------------------------------#
# record the HEAD commit-id for each repository #
#-----------------------------------------------#
record_head_commits_function () {

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
    ### Record repository details - name and HEAD commit-id
    ###

    cd ${materialize_workspace_path}_git
    repositories_recorded=0
    echo "# List of HEAD commits in repositories in ${materialize_workspace_path}_git/"
    echo "# Written `date +"%a %d/%b/%Y %H:%M:%S %z"` (${BUILD_URL:-\$BUILD_URL:missing})"
    for repository in $(ls -1 | sort); do
        if [[ ! -f "${materialize_workspace_path}_git/${repository}/.git/config" ]]; then
            echo "# Skipping ${materialize_workspace_path}_git/${repository} since it does not appear to be a Git repository"
        else
            url=$(cd ${materialize_workspace_path}_git/${repository}/ && git config --get remote.origin.pushurl)
            if [[ -z "${url}" ]]; then
                url=$(cd ${materialize_workspace_path}_git/${repository}/ && git config --get remote.origin.url)
            fi
            commitid=$(cd ${materialize_workspace_path}_git/${repository}/ && git rev-parse --verify HEAD)
            branch=$(cd ${materialize_workspace_path}_git/${repository}/ && git rev-parse --abbrev-ref HEAD)
            echo "repository=${repository}***URL=${url}***HEAD=${commitid}***BRANCH=${branch}***"
            (( repositories_recorded += 1 ))
        fi
    done
    echo "# Repositories reported on = ${repositories_recorded}"

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#-------------------------------------#
# record the target platform contents #
#-------------------------------------#
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
    echo "# Written `date +"%a %d/%b/%Y %H:%M:%S %z"` (${BUILD_URL:-\$BUILD_URL:missing})"

    # TODO - extract names and versions

    echo "# Features reported on = ${features_recorded}"
    echo "# Plugins reported on = ${plugins_recorded}"

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#-------------------------------------------------------#
# record what projects were imported into the workspace #
#-------------------------------------------------------#
record_workspace_projects_function () {

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
    ### Record workspace details - project names imported
    ###

    cd ${materialize_workspace_path}/.metadata/.plugins/org.eclipse.core.resources/.projects
    projects_recorded=0
    echo "# List of projects imported from ${materialize_workspace_path}_git/"
    echo "# Written `date +"%a %d/%b/%Y %H:%M:%S %z"` (${BUILD_URL:-\$BUILD_URL:missing})"
    for project in $(ls -1 | sort); do
        if [[ -d "${project}" ]]; then
            if [[ ! -L "${project}" ]]; then
                echo "project=${project}***"
                (( projects_recorded += 1 ))
            fi
        fi
    done
    echo "# Projects reported on = ${projects_recorded}"

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

