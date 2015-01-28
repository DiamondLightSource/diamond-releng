# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh Dawn${Dawn_flavour}.${Dawn_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit.tests.clean_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_head_commits_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_targetplatform_contents_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit_function.sh

# no need to clean if we are going to do a fresh materialize (match on "discard" not "fresh", since "fresh" occurs in the txt for more than one materialize_type)
if [[ "$(echo ${materialize_type:-unknown} | tr '[:upper:]' '[:lower:]')" != *discard* ]]; then
    junit_tests_clean_function
fi

materialize_function

mkdir -pv ${WORKSPACE}/artifacts_to_archive/
record_head_commits_function > ${WORKSPACE}/artifacts_to_archive/materialized_head_commits.txt
record_targetplatform_contents_function > ${WORKSPACE}/artifacts_to_archive/materialized_targetplatform_contents.txt

if [[ "$(type -t pre_build_function)" == "function" ]]; then
    pre_build_function
fi
build_function
if [[ "$(type -t post_build_function)" == "function" ]]; then
    post_build_function
fi

junit_function
