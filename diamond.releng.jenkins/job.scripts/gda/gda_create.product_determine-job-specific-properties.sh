# Write job-specific information into a file in the form of name=value pairs
set +x  # Turn off xtrace

properties_filename=${WORKSPACE}/job-specific-environment-variables.properties

if [[ "${GDA_beamline}" == "logpanel" || "${GDA_beamline}" == "synoptic" ]]; then
    materialize_component=uk.ac.gda.client.${GDA_beamline}.site
else
    materialize_component=${GDA_beamline:-internal_error}-config
fi

if [[ "${GDA_group}" == "DLS" ]]; then
    if [[ "${GDA_beamline}" == "excalibur" || "${GDA_beamline}" == "synoptic" ]]; then
        product_site=uk.ac.gda.client.${GDA_beamline}.site
    elif [[ "${GDA_beamline}" == "i20-1" ]]; then
        product_site=uk.ac.gda.beamline.i20_1.site
    else
        product_site=uk.ac.gda.beamline.${GDA_beamline}.site
    fi
elif [[ "${GDA_group}" == "GDA" ]]; then
    if [[ "${GDA_beamline}" == "logpanel" ]]; then
        product_site=uk.ac.gda.client.${GDA_beamline}.site
    else
        product_site=uk.ac.gda.${GDA_beamline}.site
    fi
elif [[ "${GDA_group}" == "APS" ]]; then
    product_site=gov.aps.gda.beamline.${GDA_beamline}.site
elif [[ "${GDA_group}" == "ESRF" ]]; then
    product_site=fr.esrf.gda.beamline.${GDA_beamline}.site
elif [[ "${GDA_group}" == "RAL" ]]; then
    product_site=uk.ac.rl.gda.${GDA_beamline}.site
else
    echo "internal error determining product_site"
    exit 2
fi

if [[ "${download_public:false}" == "true" ]]; then
    cat << EOF >> ${properties_filename}
pewma_py_use_public_version=true
buckminster_headless_use_public_version=true
materialize_location_option=--location=public
materialize_properties_base=\${materialize_properties_base__public_download}
EOF
fi

cat << EOF >> ${properties_filename}
materialize_component=${materialize_component}
materialize_properties_extra='-Dskip_ALL_test_fragments=true'
build_options_extra=--suppress-compile-warnings
product_site=${product_site:-internal_error}
product_options_extra=--suppress-compile-warnings
EOF

# the example beamline .properties filenames are different from the standard names defined in GDA.<release>-environment-variables.properties
if [[ "${GDA_group}" == "GDA" && "${GDA_beamline}" == "example" ]]; then
    cat << EOF >> ${properties_filename}
buckminster_properties_filename=buckminster.diamond.jenkins.properties
EOF
fi

echo "[gda_create.product_determine-job-specific-properties.sh] wrote ${properties_filename} --->"
cat ${properties_filename}
