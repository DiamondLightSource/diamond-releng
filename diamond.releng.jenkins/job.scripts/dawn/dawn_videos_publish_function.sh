#------------------------------------#
#------------------------------------#

dawn_videos_publish_function () {

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
    ### Publish as requested
    ###

    if [[ -n "${nice_setting_common:-}" ]]; then
        rsync="nice -n ${nice_setting_common} rsync"
    else
        rsync="rsync"
    fi

    set -x  # Turn on xtrace

    # publish_webserver_opengda
    echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` rsync-ing with opengda webserver ***\n"
    ${rsync} -e "${webserver_opengda_rsync_options}" --cvs-exclude --delete --omit-dir-times -irtv --chmod=ug=rw,o=r ${publish_videos_origin} ${webserver_opengda_name}:${publish_webserver_opengda_videos_dir}

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#
