#------------------------------------#
#------------------------------------#

pre_post_materialize_functions () {

if [[ "${GDA_new_config_test}" == "true" ]]; then
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gda/gda_new.config_pre.post.materialize.functions.sh
fi
if [[ "${gerrit_single_test}" == "true" ]]; then
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gerrit.single_pre.post.materialize.functions.sh
fi
if [[ "${gerrit_multiple_test}" == "true" ]]; then
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gerrit.multiple_pre.post.materialize.functions.sh
fi

}

#------------------------------------#
#------------------------------------#

