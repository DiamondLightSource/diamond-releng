# Write a file recording the standard branch names for each repository, based on what we will materialize

#------------------------------------#
#------------------------------------#

write_cquery_branches_file_function () {

    if [[ ! -f "${WORKSPACE}/artifacts_to_archive/cquery-branches-file.txt" ]]; then
        # from the CQuery, extract the standard branch names for whatever we are about to materialize
        if [[ -z "${materialize_cquery}" ]]; then
            ${pewma_py} ${log_level_option} --prepare-jenkins-build-description-on-error --cquery.branches.file=${WORKSPACE}/artifacts_to_archive/cquery-branches-file.txt get-branches-expected ${materialize_component} ${materialize_category} ${materialize_version}
        else
            ${pewma_py} ${log_level_option} --prepare-jenkins-build-description-on-error --cquery.branches.file=${WORKSPACE}/artifacts_to_archive/cquery-branches-file.txt get-branches-expected ${materialize_component} ${materialize_cquery} 
        fi
    fi
}

#------------------------------------#
#------------------------------------#
