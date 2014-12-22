export new_config_repo_parent=${WORKSPACE}/materialize_workspace_git
export need_to_clone=false

# before materialize, switch back to master
pre_materialize_function () {
   set -o verbose
   for repo in gda-core gda-diamond gda-mt; do 
       if [[ -d "${new_config_repo_parent}/${repo}.git/" ]]; then
           cd ${new_config_repo_parent}/${repo}.git/
           echo "# processing ${repo}.git"
           git branch
           git checkout master
       fi
   done
   set +o verbose
}

# after materialize, switch to new configuration
post_materialize_function () {
    . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gda_new_config/gda_switch_to_new_config.sh
}
