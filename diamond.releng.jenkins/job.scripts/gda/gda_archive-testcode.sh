# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA.${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_squish_tests_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/zip_squish_tests_function.sh

# zip squish tests, and move to the single directory that we will archive
# materialize_squish_tests_function (temporarily commented out, tests are not yet in a repository, but just on a network drive)
zip_squish_tests_function

mkdir -pv ${WORKSPACE}/artifacts_to_archive/
mv -v ${WORKSPACE}/squish_tests.zip ${WORKSPACE}/artifacts_to_archive/squish_tests.zip

