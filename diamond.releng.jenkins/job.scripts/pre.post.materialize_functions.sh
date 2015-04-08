#------------------------------------#
#------------------------------------#

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
  script=gerrit_multiple_get_changes.py
  echo "Running ${script}"
  python ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
  script=gerrit.multiple_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/gerrit.multiple_pre.post.materialize.functions.sh
fi

if [[ "${JOB_NAME}" == *~*e4* ]]; then
  script=e4_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
fi

#------------------------------------#
#------------------------------------#

