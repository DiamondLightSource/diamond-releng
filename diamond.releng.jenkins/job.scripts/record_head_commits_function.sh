# record the HEAD commit-id for each repository

#------------------------------------#
#------------------------------------#

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
    echo "# Written `date +"%a %d/%b/%Y %H:%M:%S"` in Jenkins ${BUILD_TAG} (${BUILD_URL})"
    for repository in $(ls -1 | sort); do
        if [[ ! -f "${materialize_workspace_path}_git/${repository}/.git/config" ]]; then
            echo "# Skipping ${materialize_workspace_path}_git/${repository} since it does not appear to be a Git repository"
        else
            url=$(cd ${materialize_workspace_path}_git/${repository}/ && git config --get remote.origin.url)
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

#------------------------------------#
#------------------------------------#

