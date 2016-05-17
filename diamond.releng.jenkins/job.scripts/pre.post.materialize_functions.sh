#------------------------------------#
#------------------------------------#

if [[ -n "${GDA_release}" ]]; then
  script_path=diamond-releng.git/diamond.releng.jenkins/job.scripts/gda/gda_pre.post.materialize.functions.sh
  echo "Sourcing ${script_path}"
  . ${WORKSPACE}/${script_path}
fi

#------------------------------------#
#------------------------------------#

pre_materialize_function_stage1_dawnsci () {

    dawnsci_config=${materialize_workspace_path}_git/dawnsci.git/.git/config
    if [ -f "${dawnsci_config}" ]; then
        if [[ "${materialize_dawnsci_from_DawnScience}" == "true" ]]; then
            if grep -q "/DawnScience/dawnsci.git" ${dawnsci_config}; then
                : nothing to do, the existing repo is from the correct location
            else
                rm -rf ${materialize_workspace_path}_git/dawnsci.git
            fi
        else
            if grep -q "/eclipse/dawnsci.git" ${dawnsci_config}; then
                : nothing to do, the existing repo is from the correct location
            else
                rm -rf ${materialize_workspace_path}_git/dawnsci.git
            fi
        fi
    fi

}

#------------------------------------#
#------------------------------------#

