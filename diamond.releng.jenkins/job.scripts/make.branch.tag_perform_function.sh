# perform the requested tag or branch action

#------------------------------------#
#------------------------------------#

make_branch_tag_action_perform_function () {

    if [[ -n "${tag_name}" && -z "${branch_name}" ]]; then
        action_text="tag=${tag_name}"
    elif [[ -z "${tag_name}" && -n "${branch_name}" ]]; then
        action_text="branch=${branch_name}"
    elif [[ -n "${tag_name}" && -n "${branch_name}" ]]; then
        action_text="branch=${branch_name}/tag=${tag_name}"
    else
        echo "internal error, impossible missing tag_name=*${tag_name}* branch_name=*${branch_name}*"
        return 100
    fi

    mkdir -pv ${WORKSPACE}/artifacts_to_archive/
    cp -pv ${WORKSPACE}/artifacts_to_publish/head_commits.txt ${WORKSPACE}/artifacts_to_archive/ 

    python ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/make_branch_tag_generate_script.py ${WORKSPACE}/make_branch_tag_tmp > ${WORKSPACE}/artifacts_to_archive/make_branch_tag_script.sh
    if [[ "$(echo ${make_branch_tag_action:-none} | tr '[:upper:]' '[:lower:]')" == *push* ]]; then
        echo "*** Script to perform tag or branch action generated, now running ..."
        . ${WORKSPACE}/artifacts_to_archive/make_branch_tag_script.sh
        build_description_start="committed/pushed"
    else
        echo "*** Script to perform tag or branch action generated, but will not be run"
        build_description_start="saved <a href=\"/job/${JOB_NAME}/${BUILD_NUMBER}/artifact/artifacts_to_archive/\">script</a> to"
    fi
    echo "set-build-description: ${build_description_start} ${action_text} based on <a href=\"/job/${job_name_specifying_branch_point}/\">${job_name_specifying_branch_point}</a> build <a href=\"/job/${job_name_specifying_branch_point}/${copyartifact_build_number}/\">${copyartifact_build_number}</a>"

}

#------------------------------------#
#------------------------------------#
