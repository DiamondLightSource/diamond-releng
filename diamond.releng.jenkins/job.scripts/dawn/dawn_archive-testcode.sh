# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh Dawn${DAWN_flavour}.${DAWN_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/materialize_squish_tests_function.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/zip_squish_tests_function.sh

# zip squish tests, and move to the single directory that we will archive
materialize_squish_tests_function
zip_squish_tests_function
if [[ "${zip_squish_tests}" == "true" ]]; then
  mv -v ${WORKSPACE}/squish_tests.zip ${buckminster_root_prefix}/products/squish_tests.zip
fi
