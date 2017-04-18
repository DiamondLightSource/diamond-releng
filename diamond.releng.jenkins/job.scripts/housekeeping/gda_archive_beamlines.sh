# clean up beamlines

#------------------------------------#
#------------------------------------#

perform_find_and_action () {
    # find_command            must be set and non-empty
    # initial_command         must be set, but may be non-empty
    # per_file_command        must be set and non-empty
    if [[ -z "${find_command}" ]]; then
        echo '$find_command variable was not set - exiting'
        return 1
    fi
    if [[ -z "${per_file_command}" ]]; then
        echo '$per_file_command variable was not set - exiting'
        return 1
    fi

    count=$(find ${find_command} | wc -l)
    echo "${count} items found by \"find ${find_command}\""
    if [[ "${count}" != "0" ]]; then
        if [[ "${dryrun}" != "false" ]]; then
            find ${find_command} -print
        else
            if [[ -n "${initial_command}" ]]; then
                echo "Running ${initial_command} ..."
                ${initial_command}
            fi
            find ${find_command} -exec ${per_file_command} \; || true
        fi
    fi

    unset find_command
    unset expects initial_command
    unset expects per_file_command

}

#------------------------------------#

archive_beamline () {

    if [[ -z "${beamline}" ]]; then
        echo '$beamline variable was not set - exiting'
        return 1
    fi
    echo -e "\n********************************************************************************"
    echo -e "*** `date +"%a %d/%b/%Y %H:%M:%S %z"` Processing beamline ${beamline} ***"
    echo -e "********************************************************************************"
    if [[ "${dryrun}" != "false" ]]; then
        echo 'Running in dryrun mode ($dryrun != false)'
    fi

    # Move old logs to archive (GDA 8 log locations)
    parent_dir="/dls_sw/${beamline}/logs"
    archive_dir=/dls/science/groups/das/Archive/${beamline}/logs
    if [[ -d "${parent_dir}" ]]; then
        echo -e "\n$(date '+%a %d/%b/%Y %H:%M:%S %z') Moving files older than 30 days from ${parent_dir} to ${archive_dir} ..."
        find_command="${parent_dir} -mindepth 1 -maxdepth 1 -type f -mtime +30"
        initial_command="mkdir -pv ${archive_dir}"
        per_file_command="mv -v \"{}\" ${archive_dir}"
        perform_find_and_action
    fi

    # Move old logs to archive (GDA 9 log locations)
    for type in client servers logpanel; do
        parent_dir="/dls_sw/${beamline}/logs/gda_${type}_output"
        archive_dir="/dls/science/groups/das/Archive/${beamline}/logs/gda_${type}_output"
        if [[ -d "${parent_dir}" ]]; then
            echo -e "\n$(date '+%a %d/%b/%Y %H:%M:%S %z') Moving files older than 30 days from ${parent_dir} to ${archive_dir} ..."
            find_command="${parent_dir} -mindepth 1 -maxdepth 1 -type f -mtime +30"
            initial_command="mkdir -pv ${archive_dir}"
            per_file_command="mv -v \"{}\" ${archive_dir}"
            perform_find_and_action
        fi
    done

    # Compress old logs (GDA 8 log locations)
    parent_dir="/dls_sw/${beamline}/logs"
    filename_pattern='gda_output_*.txt'
    if [[ -d "${parent_dir}" ]]; then
        echo -e "\n$(date '+%a %d/%b/%Y %H:%M:%S %z') Compressing files older than 7 days in ${parent_dir}, matching ${filename_pattern} ..."
        find_command="${parent_dir} -mindepth 1 -maxdepth 1 -type f -name "${filename_pattern}" -mtime +7"
        initial_command=""
        per_file_command="gzip \"{}\""
        perform_find_and_action
    fi

    # Compress old logs (GDA 9 log locations)
    for type in client servers logpanel; do
        parent_dir="/dls_sw/${beamline}/logs/gda_${type}_output"
        filename_pattern="gda_${type}_output_"'*.txt'
        if [[ -d "${parent_dir}" ]]; then
            echo -e "\n$(date '+%a %d/%b/%Y %H:%M:%S %z') Compressing files older than 7 days in ${parent_dir}, matching ${filename_pattern} ..."
            find_command="${parent_dir} -mindepth 1 -maxdepth 1 -type f -name "${filename_pattern}" -mtime +7"
            initial_command=""
            per_file_command="gzip \"{}\""
            perform_find_and_action
        fi
    done

    # Delete old files from var/ (excluding jythonCache/, which might be in active use)
    # From Charles:
    #   Can the removal of old files from var please _not_ be run against I16.
    #   They have some old persistence stuff there (which, despite having mtime dates going back over a year, I think might still be used).
    if [[ "${beamline}" == "i16" ]]; then
        return
    fi
    parent_dir="/dls_sw/${beamline}/var"
    if [[ -d "${parent_dir}" ]]; then
        echo -e "\n$(date '+%a %d/%b/%Y %H:%M:%S %z') Deleting files older than 1 year from ${parent_dir} (excluding jythonCache/, motorPositions/, .ssh/) ..."
        find_command="${parent_dir} -mindepth 1 -type f -not -path */jythonCache/* -not -path */motorPositions/* -not -path */.ssh/* -mtime +365"
        initial_command=""
        per_file_command="-delete"
        perform_find_and_action
    fi

    # Remove empty directories files from var/
    parent_dir="/dls_sw/${beamline}/var"
    if [[ -d "${parent_dir}" ]]; then
        echo -e "\n$(date '+%a %d/%b/%Y %H:%M:%S %z') Removing empty directories from ${parent_dir} ..."
        find_command="${parent_dir} -mindepth 1 -type d -empty"
        initial_command=""
        per_file_command="-delete"
        perform_find_and_action
    fi

    echo -e "-- end of ${beamline} cleanup\n"
}

#------------------------------------#
#------------------------------------#

