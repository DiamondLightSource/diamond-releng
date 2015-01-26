# Write job-specific information into a file in the form of name=value pairs
set +x  # Turn off xtrace

properties_filename=${WORKSPACE}/job-specific-environment-variables.properties

if [[ "${download_public:false}" == "true" ]]; then
    cat << EOF >> ${properties_filename}
pewma_py_use_public_version=true
buckminster_headless_use_public_version=true
materialize_location_option=--location=public
materialize_properties_base=\${materialize_properties_base__public_download}
EOF
fi

cat << EOF >> ${properties_filename}
materialize_properties_extra='-Dskip_ALL_test_fragments=true'
build_options_extra=--suppress-compile-warnings
product_options_extra=--suppress-compile-warnings
EOF

echo "[dawn_create.product_determine-job-specific-properties.sh] wrote ${properties_filename} --->"
cat ${properties_filename}

