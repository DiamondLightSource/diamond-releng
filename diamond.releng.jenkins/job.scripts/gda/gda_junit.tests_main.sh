# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit.tests.clean_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_head_commits_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit_function.sh

# no need to clean if we are going to do a fresh materialize
if [[ "${materialize_type:-unknown}" != *fresh* ]]; then
    junit_tests_clean_function
fi

if [[ "$(type -t pre_materialize_function)" == "function" ]]; then
    pre_materialize_function
fi
materialize_function
if [[ "$(type -t post_materialize_function)" == "function" ]]; then
    post_materialize_function
fi

mkdir -pv ${WORKSPACE}/artifacts_to_archive/
record_head_commits_function > ${WORKSPACE}/artifacts_to_archive/head_commits.txt

if [[ "$(type -t pre_build_function)" == "function" ]]; then
    pre_build_function
fi
build_function
if [[ "$(type -t post_build_function)" == "function" ]]; then
    post_build_function
fi

junit_function
