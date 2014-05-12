### Start servers for testing

print_and_exec () {
    # parameter 1 = command to execute
    # parameter 2 = filename to redirect all output to
    echo "$1 >$2 2>&1"
    $1 >$2 2>&1
    }

servers_start () {
    echo -e "\n$(date +"%a %d/%b/%Y %H:%M:%S") ==== Starting GDA servers ===="

    # determine the configuration we are testing
    config_dir=$(find /scratch/aut_other/materialize_workspace_git -type d -name ${config_dir_basename} | xargs -i find {} -mindepth 1 -maxdepth 1 -type f -name ".project" | xargs -i dirname {})
    config_dir_count=$(echo "${config_dir}" | wc -l)
    if [ "${config_dir_count}" != "1" ]; then
        echo "Found ${config_dir_count} matches for $""{config_dir_basename}=${config_dir_basename} in /scratch/aut_other/materialize_workspace_git, so terminating"
        return 100
    fi
    export GDA_CONFIG=${config_dir}

    export GDA_SERVER_LOGDIR="${WORKSPACE}/server_test_logs"
    rm -rf ${GDA_SERVER_LOGDIR}
    mkdir ${GDA_SERVER_LOGDIR}


    echo "Running with GDA_CONFIG=${GDA_CONFIG}"
    echo "Running with gda_server_test_options=${gda_server_test_options}"
    echo "Running with GDA_SERVER_LOGDIR=${GDA_SERVER_LOGDIR}"

    export gda_command="python /scratch/aut_other/materialize_workspace_git/gda-core.git/uk.ac.gda.core/bin/gda"
    print_and_exec "$gda_command servers --stop  --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/00-stop_old_servers.log"
    sleep 20

    print_and_exec "$gda_command logserver --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/11-logserver.log"
    sleep 2

    print_and_exec "$gda_command nameserver --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/12-nameserver.log"
    sleep 2

    print_and_exec "$gda_command eventserver --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/13-channelserver.log"
    sleep 2

    if [[ -n "${additional_objectserver_profile}" ]]; then
        print_and_exec "$gda_command objectserver --verbose --profile=${additional_objectserver_profile} ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/14-objectserver-${additional_objectserver_profile}.log"
        sleep 2
    fi

    print_and_exec "$gda_command objectserver --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/15-objectserver-main.log"
    sleep 30
  }

servers_start
