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

if [[ "${gerrit_manual_test}" == "true" ]]; then
  mkdir -pv ${WORKSPACE}/artifacts_to_archive

  script=gerrit_manual_get_changes.py
  echo "Running ${script}"
  set +e  # Turn off errexit
  python ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
  RETVAL=$?
  set -e  # Turn on errexit
  cat ${WORKSPACE}/artifacts_to_archive/gerrit_changes_tested.txt
  if [[ "${RETVAL}" != "0" ]]; then
      echo "Problems with specification of changes to test, so exiting"
      exit 1
  fi

  script=artifacts_to_archive/gerrit.manual_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/${script}
fi

if [[ "${JOB_NAME}" == *~*e4* ]]; then
  script=e4_pre.post.materialize.functions.sh
  echo "Sourcing ${script}"
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/${script}
fi

#------------------------------------#
#------------------------------------#

