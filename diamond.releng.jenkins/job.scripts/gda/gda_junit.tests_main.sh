# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit.tests.clean_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
if [[ "${new_config_test}" == "true" ]]; then
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gda/gda_new.config_pre.post.materialize.functions.sh
fi
if [[ "${gerrit_test}" == "true" ]]; then
  . ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/gda/gda.gerrit_pre.post.materialize.functions.sh
fi
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_head_commits_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_targetplatform_contents_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit_function.sh

# no need to clean if we are going to do a fresh materialize
if [[ "$(echo ${materialize_type:-unknown} | tr '[:upper:]' '[:lower:]')" != *fresh* ]]; then
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
