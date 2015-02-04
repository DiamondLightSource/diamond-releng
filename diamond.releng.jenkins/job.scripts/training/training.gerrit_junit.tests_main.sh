# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.post.materialize_functions.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh

# remove old JUnit test report files from a previous run, so that Jenkins post-build cannot find them
rm -f ${WORKSPACE}/TEST-gda.training.DummyTest.xml

materialize_function

# simulate running JUnit tests - copy either a "passed" (chance: 3/4) or "failed" (chance: 1/4) result file
number=$RANDOM
let "number %= 3"
if [[ "${number}" == "0" ]]; then
    file_to_copy=TEST-failed.xml
else
    file_to_copy=TEST-passed.xml
fi
cp -v ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/training/${file_to_copy} ${WORKSPACE}/TEST-gda.training.DummyTest.xml

