# Write job-specific information into a file in the form of name=value pairs
set +x  # Turn off xtrace

properties_filename=${WORKSPACE}/job-specific-environment-variables.properties

cat << EOF >> ${properties_filename}
# Written `date +"%a %d/%b/%Y %H:%M:%S %z"` (${BUILD_URL:-\$BUILD_URL:missing})
materialize_component=all-dls-config
EOF

if [[ "${JOB_NAME:-noname}" == *gerrit* ]]; then
  cat << EOF >> ${properties_filename}
build_options_extra=--suppress-compile-warnings
EOF
fi

echo "[gda_junit.tests_determine-job-specific-properties.sh] wrote ${properties_filename} --->"
cat ${properties_filename}
