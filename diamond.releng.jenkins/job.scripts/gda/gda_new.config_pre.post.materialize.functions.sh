export new_config_repo_parent=${WORKSPACE}/materialize_workspace_git
export need_to_clone=false

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.materialize_checkout.standard.branches_function.sh

pre_materialize_function_1 () {
    checkout_standard_branches_function
}

# after materialize, switch to new configuration
post_materialize_function () {

    # ***************************"
    # * Processing gda-core.git *"
    # ***************************"
    repo=gda-core
    cd ${materialize_workspace_path}_git/${repo}.git

    # make a new local branch - we'll do our changes in this, to avoid any risk of pushing something back to the remote
    git checkout master
    git branch -D local-GDA-6009b || true
    git branch -vv --no-track local-GDA-6009b remotes/origin/GDA-6009b
    git checkout local-GDA-6009b
    git status

    # rebase the local branch on top of master
    git rebase --verbose master 
    git status

    # now try merging in the "final" changes (NB get Java compile errors, so skip this step for the moment)
    # git merge --verbose --squash remotes/origin/GDA-6009-final-cleanup
    # git commit -m "GDA-6009 complete switch to new configuration layout"
    # git status

    # see what we have in advance of master
    git log master^..

    # *******************************"
    # ** Processing gda-diamond.git *"
    # ******************************"
    repo=gda-diamond
    cd ${materialize_workspace_path}_git/${repo}.git

    # make a new local branch - we'll do our changes in this, to avoid any risk of pushing something back to the remote
    git checkout master
    git branch -D local-GDA-6009b || true
    git branch -vv --no-track local-GDA-6009b remotes/origin/GDA-6009b
    git checkout local-GDA-6009b
    git status

    # rebase the local branch on top of master
    git rebase --verbose master 
    git status

    # no "final" changes to merge in 
    #git merge --verbose --squash remotes/origin/GDA-6009-final-cleanup
    #git commit -m "GDA-6009 complete switch to new configuration layout"
    #git status

    # see what we have in advance of master
    git log master^..

    # *******************************"
    # ** Processing gda-mt.git *"
    # ******************************"
    repo=gda-mt
    if [[ -d "${materialize_workspace_path}_git/${repo}.git" ]]; then
        cd ${materialize_workspace_path}_git/${repo}.git

        # make a new local branch - we'll do our changes in this, to avoid any risk of pushing something back to the remote
        git checkout master
        git branch -D local-GDA-6009b || true
        git branch -vv --no-track local-GDA-6009b remotes/origin/GDA-6009b-group
        git checkout local-GDA-6009b
        git status

        # rebase the local branch on top of master
        git rebase --verbose master 
        git status

        # now try merging in the "instance" changes
        # git merge --verbose --squash remotes/origin/GDA-6009b-b24  <-- the replay version
        git merge --verbose --squash remotes/origin/GDA-6009-b24-working-prototype
        git commit -m "GDA-6009 new configuration layout changes for b24"
        git status

        # now try merging in the "final" changes
        git merge --verbose --squash remotes/origin/GDA-6009-final-cleanup
        git commit -m "GDA-6009 complete switch to new configuration layout"
        git status

        # see what we have in advance of master
        git log master..
    fi

}
