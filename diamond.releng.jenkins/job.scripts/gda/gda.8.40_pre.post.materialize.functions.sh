# handle branch switching for GDA 8.40 test jobs

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.materialize_checkout.standard.branches_function.sh

pre_materialize_function_stage2_gda_8_40 () {

    repo=gphl-abstract-beamline.git
    commit=e81d221270876ddca7b9059b718a41c2ad303aec
    if [[ -d "${materialize_workspace_path}_git/${repo} ]]; then
        git -C ${materialize_workspace_path}_git/${repo} checkout ${commit}
    fi

    repo=gphl-astra.git
    commit=d2f697b77283a946e51c050c9e3390b27b3ac66a
    if [[ -d "${materialize_workspace_path}_git/${repo} ]]; then
        git -C ${materialize_workspace_path}_git/${repo} checkout ${commit}
    fi

}
