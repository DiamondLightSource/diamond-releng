# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh Dawn${Dawn_flavour}.${Dawn_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_head_commits_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create_p2_site_product_function.sh

materialize_function

record_head_commits_function > ${WORKSPACE}/head_commits.txt
# also record the current head in repos that might not have been materialized, but we still need to branch when making a release
for extra_repo in "dawn-test.git"; do
    if ! grep -q "${extra_repo}" ${WORKSPACE}/head_commits.txt; then
        echo -n "repository=${extra_repo}***URL=git://github.com/DawnScience/${extra_repo}***" >> ${WORKSPACE}/head_commits.txt
        echo -n "HEAD=$(git ls-remote git@github.com:DawnScience/${extra_repo} refs/heads/master | cut -f 1)***" >> ${WORKSPACE}/head_commits.txt
        echo "BRANCH=master***" >> ${WORKSPACE}/head_commits.txt
        echo "Appended to head_commits.txt: $(tail -n 1 ${WORKSPACE}/head_commits.txt)"
    fi
done

build_function
create_p2_site_product_function

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_create.product_save-product-version-number.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create.product_set-build-description.sh
mv -v ${WORKSPACE}/head_commits.txt ${buckminster_root_prefix}/products/head_commits.txt
