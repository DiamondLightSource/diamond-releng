# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties
if [[ -n "${non_beamline_product}" ]]; then
    . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/properties/GDA.${GDA_release}-product-${non_beamline_product}.properties
fi

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.post.materialize_functions.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/update_single_git_repo_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_materialization_functions.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create_p2_site_product_function.sh

materialized_info_path=${WORKSPACE}/artifacts_to_archive

materialize_function

record_head_commits_function > ${materialized_info_path}/materialized_head_commits.txt
record_workspace_projects_function > ${materialized_info_path}/materialized_project_names.txt
record_targetplatform_contents_function > ${materialized_info_path}/materialized_targetplatform_contents.txt

if [[ "$(type -t pre_build_function)" == "function" ]]; then
    pre_build_function
fi
build_function
if [[ "$(type -t post_build_function)" == "function" ]]; then
    post_build_function
fi

create_p2_site_product_function

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gda/gda_create.product_save-product-version-number.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create.product_set-build-description.sh
