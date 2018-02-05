# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit.tests.clean_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.post.materialize_functions.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/update_single_git_repo_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_materialization_functions.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit.ignore.selected.tests_function.sh

# remove old JUnit test report files from a previous run, so that Jenkins post-build cannot find them
m_t="$(echo ${materialize_type:-unknown} | tr '[:upper:]' '[:lower:]' | cut -d ' ' -f1)"
if [[ "${m_t}" != "extra-materialize" ]]; then
if [[ "${m_t}" != "fresh" ]]; then
    junit_tests_clean_function
fi
fi

materialized_info_path=${WORKSPACE}/artifacts_to_archive

materialize_function

record_head_commits_function > ${materialized_info_path}/materialized_head_commits.txt
record_workspace_projects_function > ${materialized_info_path}/materialized_project_names.txt
record_targetplatform_contents_function > ${materialized_info_path}/materialized_targetplatform_contents.txt

# simulate running JUnit tests - copy either a "passed" (chance: 3/4) or "failed" (chance: 1/4) result file
number=$RANDOM
let "number %= 3" || true
if [[ "${number}" == "0" ]]; then
    file_to_copy=TEST-failed.xml
else
    file_to_copy=TEST-passed.xml
fi

mkdir -pv ${materialize_workspace_path}_git/training-gerrit-1.git/test-reports/
cp -vf ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/training/${file_to_copy} ${materialize_workspace_path}_git/training-gerrit-1.git/test-reports/TEST-gda.training.DummyTest.xml

