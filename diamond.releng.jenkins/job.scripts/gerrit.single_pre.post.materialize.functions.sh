# handle branch switching for Gerrit test jobs (which should run with a materialize type of "recreate")

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.materialize_checkout.standard.branches_function.sh

pre_materialize_function_stage2_gerrit_single () {
    repo=${materialize_workspace_path}_git/$(basename ${GERRIT_PROJECT}).git
    repo_branch_env_var="repo_$(basename "${GERRIT_PROJECT}" | sed s'#^./##' | sed s'/.git$//' |  sed s'/-/_/g')_BRANCH"
    repo_branch="${!repo_branch_env_var}"
    if [[ -z "${repo_branch}" ]]; then
        repo_branch=${repo_default_BRANCH}
    fi

    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S UTC%z"` getting Gerrit patch ${GERRIT_PROJECT} ${GERRIT_REFSPEC} (branch ${repo_branch}) ***\n"

    if [[ ! -d "${repo}" ]]; then
        mkdir -pv ${materialize_workspace_path}_git
        cd ${materialize_workspace_path}_git
        git clone ${GERRIT_SCHEME}://${GERRIT_HOST}:${GERRIT_PORT}/${GERRIT_PROJECT} ${repo}
    fi

    # do the merge or rebase in a new local branch, to avoid any risk of pushing something back to the remote
    cd ${repo}
    git checkout ${repo_branch}
    git branch -D local-${JOB_NAME} || true
    git branch -vv --no-track local-${JOB_NAME} remotes/origin/${repo_branch}
    git checkout local-${JOB_NAME}
    git fetch origin ${GERRIT_REFSPEC}

    # Merge or rebase the change on the (local version of the) main branch, using whatever method is specified for Gerrit's "Submit Type:" for the repository
    if [[ "${GERRIT_USE_DIGEST_AUTHENTICATION:-true}" != "false" ]]; then
        submit_type=$(curl --silent --fail --digest -K ~/passwords/http-password_Gerrit_for-curl.txt "http://${GERRIT_HOST}:8080/a/projects/$(echo ${GERRIT_PROJECT} | sed 's#/#%2F#g')/config" | grep '"submit_type"')
    else
        submit_type=$(curl --silent --fail "http://${GERRIT_HOST}:8080/projects/$(echo ${GERRIT_PROJECT} | sed 's#/#%2F#g')/config" | grep '"submit_type"')
    fi
    if [[ "${submit_type}" == *REBASE_IF_NECESSARY* ]]; then
        # option - attempt to rebase the change with the main branch
        git checkout -f FETCH_HEAD
        git rebase --verbose local-${JOB_NAME}
    else
        # option - attempt to merge the change with the (local version of the) main branch
        git merge --verbose FETCH_HEAD
    fi

    git log ${repo_branch}^.. --topo-order

}
