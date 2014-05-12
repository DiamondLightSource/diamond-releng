# delete any previously tested artifacts
rm -rf ${WORKSPACE}/artifacts_to_test

# delete any previous squish tests materialize
rm -rf ${WORKSPACE}/materialize_workspace
rm -rf ${WORKSPACE}/materialize_workspace_git

# delete any previous results
rm -rf ${WORKSPACE}/squish_results
rm -f ${WORKSPACE}/squish_results.zip

# delete any previous GDA server logs
rm -rf ${WORKSPACE}/server_test_logs

# get Squish licence key
if [[ -f "${SQUISH_LICENCE_FILE}" ]]; then
    cp -pv ${SQUISH_LICENCE_FILE} ${SQUISH_CONTROL_DIR}/
fi
