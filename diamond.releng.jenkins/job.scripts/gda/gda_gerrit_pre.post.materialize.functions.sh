# handle branch switching for Gerrit test jobs (which should run with a materialize type of "recreate"). 

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.materialize_checkout.standard.branches_function.sh

pre_materialize_function_1 () {
    checkout_standard_branches_function
}

pre_materialize_function_2 () {
    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S"` getting Gerrit patch ${GERRIT_PROJECT} ${GERRIT_REFSPEC} ***\n"
    repo=${materialize_workspace_path}_git/$(basename ${GERRIT_PROJECT}).git
    if [[ ! -d "${repo}" ]]; then
        cd ${materialize_workspace_path}_git
        git clone ${GERRIT_SCHEME}://${GERRIT_HOST}:${GERRIT_PORT}/${GERRIT_PROJECT} ${repo}
        git -C ${repo} checkout ${repo_branch_name_for_release}
    fi
    cd ${repo}
    git fetch origin ${GERRIT_REFSPEC}
    git checkout -f FETCH_HEAD
    git clean -fdx

}
