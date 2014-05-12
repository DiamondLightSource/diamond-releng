# check that request tag action parameters are consistent

#------------------------------------#
#------------------------------------#

make_branch_tag_parameter_check_function () {

    if [[ -z "${tag_name}${tag_commitmsg}${branch_name}" ]]; then
        echo "no tag nor branch details were specified, so terminating"
        return 100
    fi
    if [[ -n "${tag_name}" && -z "${tag_commitmsg}" ]]; then
        echo "tag_name was specified, but tag_commitmsg was not, so terminating"
        return 100
    fi
    if [[ -z "${tag_name}" && -n "${tag_commitmsg}" ]]; then
        echo "tag_commitmsg was specified, but tag_name was not, so terminating"
        return 100
    fi

}

#------------------------------------#
#------------------------------------#
