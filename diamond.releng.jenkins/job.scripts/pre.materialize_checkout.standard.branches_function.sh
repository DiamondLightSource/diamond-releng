# switch back to the standard branches for each repository (used to after Gerrit tests, which create a new local branch)

#------------------------------------#
#------------------------------------#

checkout_standard_branches_function () {

    if [[ -d "${materialize_workspace_path}_git" ]]; then

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

        set -x  # Turn on xtrace

        echo -e "\n  *** `date +"%a %d/%b/%Y %H:%M:%S"` Switching all repos back to branch ${repo_branch_name_for_release:-Error} ***\n  "

        cd ${materialize_workspace_path}_git
        for repo in $(find -mindepth 1 -maxdepth 1 -type d -name "*.git" | sort); do
            git -C ${materialize_workspace_path}_git/${repo} checkout ${repo_branch_name_for_release}
        done

        $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
        $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
        $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
        $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

    fi

}

#------------------------------------#
#------------------------------------#

