# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA-${GDA_release}-environment-variables.properties

# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA-${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_squish_tests_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/zip_squish_tests_function.sh

export materialize_type=fresh
materialize_squish_tests_function
zip_squish_tests_function
mv -v ${WORKSPACE}/squish_tests.zip ${WORKSPACE}/artifacts_to_test/squish_tests.zip
