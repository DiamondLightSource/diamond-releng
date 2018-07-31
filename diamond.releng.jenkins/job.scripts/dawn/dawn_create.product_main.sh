# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh Dawn${DAWN_flavour}.${DAWN_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.post.materialize_functions.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/update_single_git_repo_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_materialization_functions.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create_p2_site_product_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_make_windows_installer_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_make_macosx_zipfile_function.sh

materialized_info_path=${WORKSPACE}/artifacts_to_archive

materialize_function

record_head_commits_function > ${materialized_info_path}/materialized_head_commits.txt
# also record the current head in repos that might not have been materialized, but we still need to branch when making a release
for extra_repo in "dawn-test"; do
    if ! grep -q "${extra_repo}.git" ${materialized_info_path}/materialized_head_commits.txt; then
        extra_repo_branch=$(grep ${extra_repo} ${materialized_info_path}/cquery-branches-file.txt | cut -d = -f 2)
        if [[ -n "${extra_repo_branch}" ]]; then
            echo -n "repository=${extra_repo}.git***URL=git://github.com/DawnScience/${extra_repo}.git***" >> ${materialized_info_path}/materialized_head_commits.txt
            echo -n "HEAD=$(git ls-remote git@github.com:DawnScience/${extra_repo}.git refs/heads/${extra_repo_branch} | cut -f 1)***" >> ${materialized_info_path}/materialized_head_commits.txt
            echo "BRANCH=${extra_repo_branch}***" >> ${materialized_info_path}/materialized_head_commits.txt
            echo "Appended to materialized_head_commits.txt: $(tail -n 1 ${materialized_info_path}/materialized_head_commits.txt)"
        else
            echo "ERROR in determining branch name for ${extra_repo}.git, so could not determine HEAD commit"
        fi
    fi
done
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

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_create.product_save-product-version-number.sh

dawn_make_windows_installer_function
dawn_make_macosx_zipfile_function

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create.product_set-build-description.sh

