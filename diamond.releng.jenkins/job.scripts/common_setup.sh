# delete any previously generated artifacts, and recreate the directory
rm -rf ${WORKSPACE}/artifacts_to_archive/
mkdir -v ${WORKSPACE}/artifacts_to_archive/

# delete any previous specify job-specific environment variables
rm -fv ${WORKSPACE}/job-specific-environment-variables.properties
