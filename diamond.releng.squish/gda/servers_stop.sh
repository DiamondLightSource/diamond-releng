### Stop servers for testing

print_and_exec () {
    # parameter 1 = command to execute
    # parameter 2 = filename to redirect all output to
    echo "$1 >$2 2>&1"
    $1 >$2 2>&1
    }

servers_stop () {
    echo -e "\n$(date +"%a %d/%b/%Y %H:%M:%S") ==== Stopping GDA servers ===="

    print_and_exec "$gda_command objectserver --stop  --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/21-stop_objectserver-main.log"
    sleep 2

    if [[ -n "${additional_objectserver_profile}" ]]; then
        print_and_exec "$gda_command objectserver --stop --verbose --profile=${additional_objectserver_profile} ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/22-stop_objectserver-${additional_objectserver_profile}.log"
        sleep 2
    fi

    print_and_exec "$gda_command eventserver --stop  --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/23-stop_eventserver.log"
    sleep 2

    print_and_exec "$gda_command nameserver --stop  --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/24-stop_nameserver.log"
    sleep 2

    print_and_exec "$gda_command logserver --stop  --verbose ${gda_server_test_options}" "${GDA_SERVER_LOGDIR}/25-stop_logserver.log"
    sleep 20
  }

servers_stop
