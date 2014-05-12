# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA-${GDA_release}-environment-variables.properties

# source functions that we will use
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/zip_materialized_workspace_function.sh

# zip materialized workspace, and move to the single directory that we will archive
zip_materialized_workspace_function

mkdir -pv ${WORKSPACE}/artifacts_to_archive/
mv -v ${WORKSPACE}/materialized_workspace.zip ${WORKSPACE}/artifacts_to_archive/materialized_workspace.zip
