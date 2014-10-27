# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/record_head_commits_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/build_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/junit_function.sh

if type pre_materialize_function | grep -i function > /dev/null; then
    pre_materialize_function
fi
materialize_function
if type post_materialize_function | grep -i function > /dev/null; then
    post_materialize_function
fi

mkdir -pv ${WORKSPACE}/artifacts_to_archive/
record_head_commits_function > ${WORKSPACE}/artifacts_to_archive/head_commits.txt

if type pre_build_function | grep -i function > /dev/null; then
    pre_build_function
fi
build_function
if type post_build_function | grep -i function > /dev/null; then
    post_build_function
fi

junit_function
