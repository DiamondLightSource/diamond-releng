# delete any previously tested artifacts
rm -rf ${WORKSPACE}/artifacts_to_test

# delete any previous squish tests materialize
rm -rf ${WORKSPACE}/workspace
rm -rf ${WORKSPACE}/workspace_git

# delete any previous results
rm -rf ${WORKSPACE}/squish_results
rm -f ${WORKSPACE}/squish_results.zip

# delete any previous GDA server logs
rm -rf ${WORKSPACE}/server_test_logs

# get Squish license key, if one is defined and we can read it
if [[ -f "${SQUISH_LICENSE_FILE}" ]]; then
    cp -pv ${SQUISH_LICENSE_FILE} ${SQUISH_CONTROL_DIR}/ || true
fi
