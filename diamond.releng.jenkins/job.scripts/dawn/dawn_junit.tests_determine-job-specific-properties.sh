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

# only for selected releases (master), the post-build should scan for compiler warnings, and for open tasks
if [[ "${DAWN_release}" == "master" ]]; then
    cat << EOF >> ${properties_filename}
postbuild_scan_for_compiler_warnings=true
postbuild_scan_for_open_tasks=true
EOF
else
    cat << EOF >> ${properties_filename}
postbuild_scan_for_compiler_warnings=false
postbuild_scan_for_open_tasks=false
EOF
fi

echo "[dawn_junit.tests_determine-job-specific-properties.sh] wrote ${properties_filename} --->"
cat ${properties_filename}
