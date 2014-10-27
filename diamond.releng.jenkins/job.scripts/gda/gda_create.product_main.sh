# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_head_commits_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create_p2_site_product_function.sh

materialize_function
if type post_materialize_function | grep -i function > /dev/null; then
    post_materialize_function
fi

mkdir -pv ${WORKSPACE}/artifacts_to_archive/
record_head_commits_function > ${WORKSPACE}/artifacts_to_archive/head_commits.txt

build_function
if type post_build_function | grep -i function > /dev/null; then
    post_build_function
fi

create_p2_site_product_function

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gda/gda_create.product_save-product-version-number.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/create.product_set-build-description.sh
