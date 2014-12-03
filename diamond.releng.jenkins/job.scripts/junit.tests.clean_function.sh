# delete the results from any previous JUnit test run

#------------------------------------#
#------------------------------------#

junit_tests_clean_function () {

    if [[ -d "${materialize_workspace_path}" ]]; then

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

        echo -e "\n  *** `date +"%a %d/%b/%Y %H:%M:%S"` Cleaning previous JUnit test results ***\n  "

        ${pewma_py} -w ${materialize_workspace_path} tests-clean

        $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
        $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
        $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
        $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

    fi

}

#------------------------------------#
#------------------------------------#

