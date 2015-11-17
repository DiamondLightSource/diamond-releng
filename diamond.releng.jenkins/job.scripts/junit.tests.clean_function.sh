# delete the results from any previous JUnit test run

#------------------------------------#
#------------------------------------#

junit_tests_clean_function () {

    if [[ -d "${materialize_workspace_path}_git" ]]; then

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
        ### Delete old JUnit test results
        ###
    
        set -x  # Turn on xtrace

        echo -e "\n  *** `date +"%a %d/%b/%Y %H:%M:%S %z"` Attempting to clean previous JUnit test results ***\n  "

        # Process multiple repositories in parallel (xargs spawns separate processes; fail if any of them fails)
        set +e  # Turn off errexit
        find ${materialize_workspace_path}_git -type d -name "test-reports" -o -name "test-scratch" -print0 | sort --zero-terminated | xargs --null --no-run-if-empty -I % -L 1 --max-procs 20 -n 1 bash -c 'rm -rf "$@"' _
        RETVAL=$?
        set -e  # Restore errexit
        if [[ "${RETVAL}" != "0" ]]; then
            echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S %z"` delete of \"test-reports\" or \"test-scratch\" failed in some case(s); abandoning ***\n"
            return ${RETVAL}
        fi

        $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
        $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
        $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
        $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

    fi

}

#------------------------------------#
#------------------------------------#

