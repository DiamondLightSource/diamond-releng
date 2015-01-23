# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh Dawn${Dawn_flavour}.${Dawn_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_head_commits_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_targetplatform_contents_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create_p2_site_product_function.sh

materialize_function

record_head_commits_function > ${WORKSPACE}/materialized_head_commits.txt
# also record the current head in repos that might not have been materialized, but we still need to branch when making a release
for extra_repo in "dawn-test.git"; do
    if ! grep -q "${extra_repo}" ${WORKSPACE}/materialized_head_commits.txt; then
        echo -n "repository=${extra_repo}***URL=git://github.com/DawnScience/${extra_repo}***" >> ${WORKSPACE}/materialized_head_commits.txt
        echo -n "HEAD=$(git ls-remote git@github.com:DawnScience/${extra_repo} refs/heads/master | cut -f 1)***" >> ${WORKSPACE}/materialized_head_commits.txt
        echo "BRANCH=master***" >> ${WORKSPACE}/materialized_head_commits.txt
        echo "Appended to materialized_head_commits.txt: $(tail -n 1 ${WORKSPACE}/materialized_head_commits.txt)"
    fi
done
mv -v ${WORKSPACE}/materialized_head_commits.txt ${buckminster_root_prefix}/products/
record_targetplatform_contents_function > ${buckminster_root_prefix}/products/materialized_targetplatform_contents.txt

if [[ "$(type -t pre_build_function)" == "function" ]]; then
    pre_build_function
fi
build_function
if [[ "$(type -t post_build_function)" == "function" ]]; then
    post_build_function
fi

create_p2_site_product_function

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_create.product_save-product-version-number.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create.product_set-build-description.sh

