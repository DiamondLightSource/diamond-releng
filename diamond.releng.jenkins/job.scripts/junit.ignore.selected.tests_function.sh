# If specific test(s) are currently failing, and we can ignore them for purposes of setting the build status
# This means already-failing tests won't result in Jenkins passing an "UNSTABLE" status to Gerrit

#------------------------------------#
#------------------------------------#

junit_ignore_selected_tests () {

    if [[ -n "${testnames_to_ignore_pattern}" ]]; then
        if [[ -d "${materialize_workspace_path}_git" ]]; then
            find ${materialize_workspace_path}_git -type f -name "TEST-${testnames_to_ignore_pattern}\.xml" || true
            find ${materialize_workspace_path}_git -type f -name "TEST-${testnames_to_ignore_pattern}\.xml" -exec mv -v {} {}.IGNORED \; || true
        fi
    fi

}

#------------------------------------#
#------------------------------------#
