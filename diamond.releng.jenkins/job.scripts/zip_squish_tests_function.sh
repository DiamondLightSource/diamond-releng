# Zip squish tests in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

zip_squish_tests_function () {

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
    ### Zip the squish tests
    ###

    if [[ -n "${nice_setting_common:-}" ]]; then
        zip="nice -n ${nice_setting_common} zip"
    else
        zip="zip"
    fi

    # zip all squish test directories, so that the product can be tested with a matching version of tests
    # note that locations must have distinct final directory names (these would normally correspond to the project name, so should be unique anyhow)
    rm -f ${WORKSPACE}/squish_tests.zip
    zip_squish_tests=$(echo ${zip_squish_tests:-false} | tr '[:upper:]' '[:lower:]')
    set -x  # Turn on xtrace
    if [[ "${zip_squish_tests}" == "true" ]]; then
        echo -e "\n*** `date +"%a %d/%b/%Y %H:%M:%S"` zipping squish tests ***\n"
        for squish_test_location in $( (set -o posix ; set) | grep 'squish_tests_locations_' | sort | cut -f 1 -d '='); do
            cd ${!squish_test_location}/..
            zip -qr ${WORKSPACE}/squish_tests.zip $(basename ${!squish_test_location})
            set +x  # Turn off xtrace
        done
        if [ -n "${touch_timestamp}" ]; then
            touch -t ${touch_timestamp} ${WORKSPACE}/squish_tests.zip
        fi
    fi

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

