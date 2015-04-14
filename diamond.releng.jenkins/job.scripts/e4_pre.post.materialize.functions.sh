# The purpose of these functions is to rebase the SCI-5214 branch (called SCI-5214 or SCI-5214b, depending on the repo) on top of master

#------------------------------------#
#------------------------------------#

pre_materialize_function_stage1_e4 () {

    repo_list="dawn-product.git dawn-third.git dawn-ui.git embl-cca.git scisoft-ui.git"
    for repo in ${repo_list}; do
        rm -rf ${materialize_workspace_path}_git/${repo}
    done

}

#------------------------------------#
#------------------------------------#

post_materialize_function_e4 () {

    repo_list="dawn-product.git dawn-third.git dawn-ui.git embl-cca.git scisoft-ui.git"

    # check that we are on the expected branch
    for repo in ${repo_list}; do
        if [[ -d "${materialize_workspace_path}_git/${repo}" ]]; then
            if [[ "$(git -C ${materialize_workspace_path}_git/${repo} rev-parse --abbrev-ref HEAD)" != SCI-5214* ]]; then
                echo "ERROR: ${materialize_workspace_path}_git/${repo} is not on the expected branch"
                exit 2
            fi
        fi
    done

    # get rid of any changes that Eclipse made when we materialized
    for repo in ${repo_list}; do
        if [[ -d "${materialize_workspace_path}_git/${repo}" ]]; then
            git -C ${materialize_workspace_path}_git/${repo} status
            git -C ${materialize_workspace_path}_git/${repo} reset --hard HEAD
        fi
    done

    # rebase on master
    for repo in ${repo_list}; do
        if [[ -d "${materialize_workspace_path}_git/${repo}" ]]; then
            echo -e "\n******** Rebasing ${repo}"
            git -C ${materialize_workspace_path}_git/${repo} rebase --verbose origin/master
        fi
    done

}