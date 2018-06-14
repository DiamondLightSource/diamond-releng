#------------------------------------#
#------------------------------------#

if [[ -n "${GDA_release}" ]]; then
  script_path=diamond-releng.git/diamond.releng.jenkins/job.scripts/gda/gda_pre.post.materialize.functions.sh
  echo "Sourcing ${script_path}"
  . ${WORKSPACE}/${script_path}
fi

#------------------------------------#
#------------------------------------#

