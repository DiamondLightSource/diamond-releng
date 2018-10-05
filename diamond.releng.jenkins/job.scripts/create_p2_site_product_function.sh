# perform Buckminster create.product actions in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

create_p2_site_product_function () {

    # Save xtrace state (1=was not set, 0=was set)
    if [[ $- = *x* ]]; then
        oldxtrace=0
    else
        oldxtrace=1
    fi
    set +x  # Turn off xtrace

    # Save errexit state (1=was not set, 0=was set)
    if [[ $- = *e* ]]; then
        olderrexit=0
    else
        olderrexit=1
    fi
    set -e  # Turn on errexit

    ###
    ### Setup environment
    ###

    # create list of platforms for which we need to create the product (this might be empty)
    platform_list=" "
    for platform in linux64 windows64 mac64; do
        platform__indirect=platform_${platform}
        if [[ "$(echo ${!platform__indirect:-false} | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
            platform_list="${platform_list}${platform} "
        fi
    done

    p2_site=$(echo ${p2_site:-false} | tr '[:upper:]' '[:lower:]')
    publish_p2_site=$(echo ${publish_p2_site:-false} | tr '[:upper:]' '[:lower:]')
    product_zip=$(echo ${product_zip:-false} | tr '[:upper:]' '[:lower:]')
    if [[ "${product_zip}" != "true" ]]; then
        if [[ "${at_least_one_publish_parameter_selected}" == "true" || "${archive_products}" == "true" || "${trigger_squish_tests}" == "true" ]]; then
            product_zip=true
        fi
    fi

    if [ "${platform_list}" != " " ]; then
        if [[ "${product_zip}" == "true" ]]; then
            buckminster_action=product.zip
        else
            buckminster_action=product
        fi
    elif [[ "${p2_site}" == "true" || "${publish_p2_site}" == "true" ]]; then
        buckminster_action=site.p2
    else
        buckminster_action=
    fi

    ###
    ### If this product build includes a bundled cpython (SCI-7275), get the python installer files
    ###

    set +e  # Turn off errexit
    grep -q "uk.ac.diamond.cpython.feature" ${materialized_info_path}/materialized_project_names.txt
    RETVAL=$?
    set -e  # Restore errexit
    if [[ "${RETVAL}" != "0" ]]; then
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Running add-diamond-cpython ***\n"
        for platform in linux.x86_64 macosx.x86_64 win32.x86_64; do
            rm -rf ${WORKSPACE}/workspace_git/diamond-cpython.git/uk.ac.diamond.cpython.${platform}/cpython*
        done
        if [ "${platform_list}" != " " ]; then
            ${pewma_py} --prepare-jenkins-build-description-on-error ${log_level_option} -w ${materialize_workspace_path} add-diamond-cpython ${platform_list}
        else
            ${pewma_py} --prepare-jenkins-build-description-on-error ${log_level_option} -w ${materialize_workspace_path} add-diamond-cpython all
        fi
    fi

    ###
    ### Create the p2 site, products(s) and zip(s)
    ###

    set -x  # Turn on xtrace

    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Creating product(s) ***\n"
    rm -rf ${buckminster_root_prefix} || return 3
    # product for all requested platforms (or just site.p2)
    if [ -n "${buckminster_action}" ]; then
        ${pewma_py} --prepare-jenkins-build-description-on-error ${log_level_option} -w ${materialize_workspace_path} --buckminster.root.prefix=${buckminster_root_prefix} --assume-build --buckminster.properties.file=${buckminster_properties_filename} ${product_options_extra} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} ${buckminster_action} ${product_site} ${platform_list} || return 1
        export platforms_built=$(find ${buckminster_root_prefix}/products/ -mindepth 1 -maxdepth 1 -type d ! -name '*.zip' ! -name '*squish*' -name '*.v[0-9]*' | wc -l)
    else
        echo "No platforms were specified, and no p2 site was requested, so skipping action"
        export platforms_built=0
    fi

    if [[ "${p2_site}" == "true" || "${publish_p2_site}" == "true" ]]; then
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Zipping p2 site ***\n"
        ${pewma_py} --prepare-jenkins-build-description-on-error ${log_level_option} -w ${materialize_workspace_path} --buckminster.root.prefix=${buckminster_root_prefix} --assume-build --buckminster.properties.file=${buckminster_properties_filename} ${product_options_extra} ${buckminster_osgi_areas} ${buckminster_extra_vmargs} site.p2.zip ${product_site} || return 1

        # move zipped p2 site to directory for archiving
        mv -v ${buckminster_root_prefix}/output/*site*/site.p2.zip/*site*.zip ${buckminster_root_prefix}/products/
    fi

    ###
    ### Set the timestamp on all artifacts to the build job time
    ###

    if [ -d "${buckminster_root_prefix}/products/" ]; then
        for z in $(ls -1 ${buckminster_root_prefix}/products/ | grep '.zip'); do
            if [ -n "${touch_timestamp}" ]; then
                touch -t ${touch_timestamp} ${buckminster_root_prefix}/products/$z
            fi
        done
    fi

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

