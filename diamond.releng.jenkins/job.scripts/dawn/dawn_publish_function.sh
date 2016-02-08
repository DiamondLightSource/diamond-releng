# publish artifacts in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

dawn_publish_function () {

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
    ### Determine options
    ###

    if [[ -z "${name_to_publish_as}" ]]; then
        echo "ERROR: $""{name_to_publish_as} not set, so terminating"
        return 100
    fi

    export publish_module_load=$(echo ${publish_module_load:-false} | tr '[:upper:]' '[:lower:]')
    export publish_webserver_diamond_zip=$(echo ${publish_webserver_diamond_zip:-false} | tr '[:upper:]' '[:lower:]')
    export publish_webserver_diamond_zip_remove_old_versions=$(echo ${publish_webserver_diamond_zip_remove_old_versions:-false} | tr '[:upper:]' '[:lower:]')
    export publish_webserver_opengda_zip_remove_old_versions=$(echo ${publish_webserver_opengda_zip_remove_old_versions:-false} | tr '[:upper:]' '[:lower:]')
    export publish_webserver_opengda_zip=$(echo ${publish_webserver_opengda_zip:-false} | tr '[:upper:]' '[:lower:]')
    export platform_linux64=$(echo ${platform_linux64:-false} | tr '[:upper:]' '[:lower:]')
    export platform_windows64=$(echo ${platform_windows64:-false} | tr '[:upper:]' '[:lower:]')
    export platform_mac64=$(echo ${platform_mac64:-false} | tr '[:upper:]' '[:lower:]')
    export publish_p2_site=$(echo ${publish_p2_site:-false} | tr '[:upper:]' '[:lower:]')

    ###
    ### Publish as requested
    ###

    if [[ -n "${nice_setting_common:-}" ]]; then
        unzip="nice -n ${nice_setting_common} unzip"
    else
        unzip="unzip"
    fi

    if [[ -n "${nice_setting_common:-}" ]]; then
        rsync="nice -n ${nice_setting_common} rsync"
    else
        rsync="rsync"
    fi

    set -x  # Turn on xtrace

    # Check that all requested platform builds are available before we proceed
    export product_version_number=$(head -q -n 1 artifacts_to_publish/product_version_number.txt)
    export platforms_requested=0
    if [[ "${publish_module_load}" == "true" || "${publish_webserver_diamond_zip}" == "true" || "${publish_webserver_opengda_zip}" == "true" ]]; then
        for platform in linux64 windows64 mac64; do
            platform__indirect="platform_${platform}"
            if [[ "${!platform__indirect}" == "true" ]]; then
                (( platforms_requested += 1 ))
                platform_count_matching=0
                for artifact in $(find ${WORKSPACE}/artifacts_to_publish/ -maxdepth 1 -type f -name '*'-${platform}.zip | xargs -i basename {}); do
                    (( platform_count_matching += 1 ))
                done
                if [[ "${platform_count_matching}" != "1" ]]; then
                    echo "Publish of platform \"${platform}\" was requested, but no artifact was found in ${WORKSPACE}/artifacts_to_publish/, so terminating"
                    return 100
                fi
            fi
        done
    fi

    # publish_module_load. note that this assumes that either:
    #     the .zip file expands into a single directory whose name is the same as the .zip filename minus the extension
    #  OR the .zip file contains the product directly at the top level of the zip
    # the assumption is controlled by file buckminster.diamond.jenkins.properties in the .site project (see zip.file.name and zip.include.parent.directory properties)
    export publish_module_load_platforms_updated=0
    export publish_module_load_platforms_skipped=0
    if [[ "${publish_module_load}" == "true" ]]; then
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Publishing to module load ***\n"
        initialize_module_load=$(echo ${initialize_module_load:-false} | tr '[:upper:]' '[:lower:]')
        if [[ "${initialize_module_load}" == "true" ]]; then
            if [[ $(uname -m) == "x86_64" ]]; then
                running_platform=linux64
            else
                running_platform=unknown
            fi
        fi
        for platform in linux64 windows64 mac64; do
            platform__indirect="platform_${platform}"
            if [[ "${!platform__indirect}" == "true" ]]; then
                echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Publishing to module load for ${platform} ***\n"
                publish_module_load_directory_for_type=${publish_module_load_directory_parent}/builds
                publish_module_load_directory_name=$(basename ${WORKSPACE}/artifacts_to_publish/*-${platform}.zip .zip)
                publish_module_load_link_name=${name_to_publish_as}-${platform}
                publish_module_load_directory=${publish_module_load_directory_for_type}/${publish_module_load_directory_name}
                publish_module_load_link=${publish_module_load_directory_for_type}/${publish_module_load_link_name}
                if [[ -e "${publish_module_load_directory}" ]]; then
                    echo "NOTE: product version already published: \"${publish_module_load_directory}\" exists"
                    (( publish_module_load_platforms_skipped += 1 ))
                else
                    if [[ $(zipinfo -1 ${WORKSPACE}/artifacts_to_publish/*-${platform}.zip ${publish_module_load_directory_name}/) ]]; then
                        ${unzip} -q ${WORKSPACE}/artifacts_to_publish/*-${platform}.zip -d ${publish_module_load_directory_for_type}
                    else
                        ${unzip} -q ${WORKSPACE}/artifacts_to_publish/*-${platform}.zip -d ${publish_module_load_directory}
                    fi
                    if [[ "${initialize_module_load}" == "true" ]]; then
                        if [[ "${running_platform}" == "${platform}" ]]; then
                            ${publish_module_load_directory_for_type}/${publish_module_load_directory_name}/dawn -initialize
                        fi
                    fi
                    chmod -R go-w ${publish_module_load_directory}/ || return 3
                    if [[ -L "${publish_module_load_link}" ]]; then
                        rm -v ${publish_module_load_link}
                    fi
                    if [[ -e "${publish_module_load_link}" ]]; then
                        echo "ERROR: exists, but is not a link: \"${publish_module_load_link}\""
                        return 255
                    fi
                    ( cd ${publish_module_load_directory_for_type} && ln -s ${publish_module_load_directory_name} ${publish_module_load_link_name} )
                    (( publish_module_load_platforms_updated += 1 ))
                fi
            fi
        done
    else
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Skipping publish to module load ***\n"
    fi

    # publish_webserver_diamond_zip
    export publish_webserver_diamond_zip_platforms_updated=0
    export publish_webserver_diamond_zip_platforms_skipped=0
    if [[ "${publish_webserver_diamond_zip}" == "true" ]]; then
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Publishing .zip to diamond webserver ***\n"
        for platform in linux64 windows64 mac64; do
            platform__indirect="platform_${platform}"
            if [[ "${!platform__indirect}" == "true" ]]; then
                echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Publishing to diamond webserver of .zip for ${platform} ***\n"
                ssh ${webserver_diamond_ssh_options} ${webserver_diamond_name} mkdir -pv ${publish_webserver_diamond_zip_directory_parent}/builds-${name_to_publish_as}/
                ${rsync} -e "${webserver_diamond_rsync_options}" -ilprtDOv --include "/*-${platform}.zip" --exclude '*' ${WORKSPACE}/artifacts_to_publish/. ${webserver_diamond_name}:${publish_webserver_diamond_zip_directory_parent}/builds-${name_to_publish_as}
                (( publish_webserver_zip_download_platforms_updated += 1 ))
                # optionally delete any old versions for this platform
                if [[ "${publish_webserver_diamond_zip_remove_old_versions}" == "true" ]]; then
                    ${rsync} -e "${webserver_diamond_rsync_options}" -ilprtDOv --include "/*-${platform}.zip" --exclude '*' --delete ${WORKSPACE}/artifacts_to_publish/. ${webserver_diamond_name}:${publish_webserver_diamond_zip_directory_parent}/builds-${name_to_publish_as}
                fi
            fi
        done
    else
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Skipping publish of .zip to diamond webserver ***\n"
    fi

    # publish_webserver_opengda_zip
    export publish_webserver_opengda_zip_platforms_updated=0
    export publish_webserver_opengda_zip_platforms_skipped=0
    if [[ "${publish_webserver_opengda_zip}" == "true" ]]; then
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Publishing .zip to opengda webserver ***\n"
        for platform in linux64 windows64 mac64; do
            platform__indirect="platform_${platform}"
            if [[ "${!platform__indirect}" == "true" ]]; then
                echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Publishing to opengda webserver of .zip for ${platform} ***\n"
                ssh ${webserver_opengda_ssh_options} ${webserver_opengda_name} mkdir -pv ${publish_webserver_opengda_zip_directory_parent}/builds-${name_to_publish_as}/
                ${rsync} -e "${webserver_opengda_rsync_options}" -ilprtDOv --include "/*-${platform}.zip" --exclude '*' ${WORKSPACE}/artifacts_to_publish/. ${webserver_opengda_name}:${publish_webserver_opengda_zip_directory_parent}/builds-${name_to_publish_as}
                (( publish_webserver_zip_download_platforms_updated += 1 ))
                # optionally delete any old versions for this platform
                if [[ "${publish_webserver_opengda_zip_remove_old_versions}" == "true" ]]; then
                    ${rsync} -e "${webserver_opengda_rsync_options}" -ilprtDOv --include "/*-${platform}.zip" --exclude '*' --delete ${WORKSPACE}/artifacts_to_publish/. ${WORKSPACE}/artifacts_to_publish/. ${webserver_opengda_name}:${publish_webserver_opengda_zip_directory_parent}/builds-${name_to_publish_as}
                fi
            fi
        done
    else
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Skipping publish of .zip to opengda webserver ***\n"
    fi

    if [ "${publish_p2_site}" == "true" ]; then
        temp_suffix=`date +"%Y%m%d_%H%M%S"`
        p2_site_unzipped=${WORKSPACE}/p2_site_unzipped
        rm -rf ${p2_site_unzipped}
        ${unzip} -q ${WORKSPACE}/artifacts_to_publish/*site*.zip -d ${p2_site_unzipped}/

        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Publishing p2 site ***\n"
        ssh ${publish_p2_ssh_options} ${publish_p2_server} mkdir -pv ${publish_p2_directory_parent}/
        ${rsync} -e "${publish_p2_rsync_options}" -ilprtDOv ${p2_site_unzipped}/ ${publish_p2_server}:${publish_p2_directory_parent}/${name_to_publish_as}_${temp_suffix}/
        # once rsync complete, rename directory
        ssh ${publish_p2_ssh_options} ${publish_p2_server} "rm -rf ${publish_p2_directory_parent}/${name_to_publish_as}/; mv -v ${publish_p2_directory_parent}/${name_to_publish_as}_${temp_suffix}/ ${publish_p2_directory_parent}/${name_to_publish_as}/"
    else
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Skipping publish of p2 site to diamond webserver ***\n"
    fi

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

