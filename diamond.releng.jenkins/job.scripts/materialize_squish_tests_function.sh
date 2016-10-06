# perform a Buckminster materialize of squish test in a Jenkins "Execute shell" build step

#------------------------------------#
#------------------------------------#

materialize_squish_tests_function () {

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
    ### Materialize the squish tests into an existing workspace
    ###

    export materialize_type=extra-materialize

    set -x  # Turn on xtrace

    materialize_squish_tests=$(echo ${materialize_squish_tests:-true} | tr '[:upper:]' '[:lower:]')
    if [[ "${materialize_squish_tests}" == "true" ]]; then
        for squish_test_component in $( (set -o posix ; set)  | grep 'squish_tests_components_' | sort | cut -f 1 -d '='); do
            export materialize_components=${!squish_test_component}
            materialize_function
        done
    fi

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

