application_name=ptypy

# check the parameters
if [[ -z "${commit_id}" ]]; then
    echo 'Error: ${commit_id} must be specified and non-null, so terminating'
    return 100
fi
if [[ "${commit_id}" != "${commit_id%[[:space:]]*}" ]]; then
    echo 'Error: ${commit_id}='"\"${commit_id}\" contains invalid characters, so terminating"
    return 100
fi

if [[ -z "${version_number}" ]]; then
    echo 'Error: ${version_number} must be specified and non-null, so terminating'
    return 100
fi
if [[ "${version_number}" != "${version_number%[[:space:]]*}" ]]; then
    echo 'Error: ${version_number}='"\"${version_number}\" contains invalid characters, so terminating"
    return 100
fi

# check that we haven't already published under this version number
publish_application_directory=/dls_sw/apps/${application_name}/${version_number}
if [[ -e "${publish_application_directory}" ]]; then
    echo "Error: \"${publish_application_directory}\" already exists, so terminating"
    return 100
fi
publish_module_load_file=/dls_sw/apps/Modules/modulefiles/${application_name}/${version_number}
if [[ -e "${publish_module_load_file}" ]]; then
    echo "Error: \"${publish_module_load_file}\" already exists, so terminating"
    return 100
fi

# clone the GitHub repository
cd $(dirname ${publish_application_directory})
git clone https://github.com/DiamondLightSource/ptypy.git ${version_number}
cd ${publish_application_directory}
git checkout ${commit_id}

# create a new entry in the "module load" system
cat > ${publish_module_load_file} <<END_OF_MODULE_FILE
#%Module1.0
##
## ptypy
##
proc ModulesHelp { } {
    global version
    puts stderr "\tSets ptypy for use"
}

module-whatis "Sets ptypy"

if { ! [is-loaded python/ana] } {
    module load python/ana
}

append-path PYTHONPATH ${publish_application_directory}

END_OF_MODULE_FILE

#report what we just wrote
cat ${publish_module_load_file}
