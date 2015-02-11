# switch to specific commits, rather than the branch head, if specified

#------------------------------------#
#------------------------------------#

post_materialize_function_gda () {

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

        cd ${materialize_workspace_path}_git
        for repo in $(find -mindepth 1 -maxdepth 1 -type d -name "*.git" | sort); do
            repo_commit_env_var="repo_$(echo "${repo}" | sed s'#^./##' | sed s'/.git$//' |  sed s'/-/_/g')_COMMIT"
            repo_commit="${!repo_commit_env_var}"
            if [[ -n "${repo_branch}" ]]; then
                git -C ${repo} checkout ${repo_branch}
            fi
        done

        $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
        $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
        $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
        $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

    fi

}

#------------------------------------#
#------------------------------------#

