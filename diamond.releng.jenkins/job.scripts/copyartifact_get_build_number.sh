# this can be run after a "Copy artifacts from another project" step has run, to determine the exact build number from which the artifacts were copied
copyartifact_variable_name=$(compgen -A variable COPYARTIFACT_BUILD_NUMBER_ | head -1)

if [ -z "${copyartifact_variable_name}" ]; then
    echo 'Could not determine $COPYARTIFACT_BUILD_NUMBER_...'
    printenv
    exit 1
fi
export copyartifact_variable_name

copyartifact_build_number=${!copyartifact_variable_name}
if [ "${copyartifact_build_number}" -eq "${copyartifact_build_number}" ] 2>/dev/null; then
    export copyartifact_build_number
else
    echo "\${${copyartifact_variable_name}} did not resolve to a number, but was \"${copyartifact_build_number}\""
fi

