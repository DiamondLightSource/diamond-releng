# Write job-specific information into a file in the form of name=value pairs
set +x  # Turn off xtrace

properties_filename=${WORKSPACE}/job-specific-environment-variables.properties

case "${GDA_beamline}" in
  i22)
    config_dir_basename=ncdsim
    ;;
  i11|i12|i13i|i13j|b18|i08|i18|i20|i20-1)
    config_dir_basename=${GDA_beamline}
    ;;
  *)
    config_dir_basename=${GDA_beamline:-internal_error}-config
    ;;
esac

case "${GDA_beamline}" in
  i22)
    gda_server_test_options=
    ;;
  *)
    gda_server_test_options=--mode=dummy
    ;;
esac


case "${GDA_beamline}" in
  i02|i03|i04|i04-1|i24)
    additional_objectserver_profile=cameraserver
    ;;
  *)
    additional_objectserver_profile=
    ;;
esac

cat << EOF >> ${properties_filename}
# Written `date +"%a %d/%b/%Y %H:%M:%S %z"` (${BUILD_URL:-\$BUILD_URL:missing})
config_dir_basename=${config_dir_basename}
gda_server_test_options=${gda_server_test_options}
additional_objectserver_profile=${additional_objectserver_profile}
EOF

echo "[gda_squish_determine-job-specific-properties.sh] wrote ${properties_filename} --->"
cat ${properties_filename}

