#------------------------------------#
#------------------------------------#

post_materialize_function_gda () {

    if [[ "${non_beamline_product}" == "gdaserver" ]]; then
        # need mapping-config (but none of its dependencies) in the workspace
        ${pewma_py} ${log_level_option} -w ${materialize_workspace_path} ${materialize_location_option} ${materialize_properties_base} ${materialize_properties_extra} -Donly_..-config.common=true ${buckminster_osgi_areas} ${buckminster_extra_vmargs} materialize mapping-config ${materialize_category} ${materialize_version} || return 1
    fi
}

#------------------------------------#
#------------------------------------#

