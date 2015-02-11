#------------------------------------#
#------------------------------------#

if [[ "${GDA_new_config_test}" == "true" ]]; then
  script=gda/gda_new.config_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
fi

if [[ -n "${GDA_release}" ]]; then
  script=gda/gda_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
fi

if [[ "${gerrit_single_test}" == "true" ]]; then
  script=gerrit.single_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
fi

if [[ "${gerrit_multiple_test}" == "true" ]]; then
  script=gerrit.multiple_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
fi

#------------------------------------#
#------------------------------------#

