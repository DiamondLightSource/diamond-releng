# reads Jenkins build parameters and identifies what changes are to be tested, and how to fetch them

#------------------------------------#
#------------------------------------#

identify_changes_to_test_function () {

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

    set -x  # Turn on xtrace

    # from the CQuery, extract the standard branch names for whatever we are about to materialize
    if [[ -z "${materialize_cquery}" ]]; then
        ${pewma_py} ${log_level_option} --cquery.branches.file=${WORKSPACE}/artifacts_to_archive/cquery-branches-file.txt get-branches-expected ${materialize_component} ${materialize_category} ${materialize_version}
    else
        ${pewma_py} ${log_level_option} --cquery.branches.file=${WORKSPACE}/artifacts_to_archive/cquery-branches-file.txt get-branches-expected ${materialize_component} ${materialize_cquery} 
    fi

    ################################################################################################
    # Analyse the Gerrit changes specified for this job, or any alternative branches to build with #
    # Build the scripts to fetch the appropriate changes (the scripts themselves are run later)    #
    ################################################################################################
    python ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/identify_changes_to_test.py

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

