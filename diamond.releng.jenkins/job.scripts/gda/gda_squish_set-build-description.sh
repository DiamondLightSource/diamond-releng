# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh

copyartifact_variable_name=$(compgen -A variable COPYARTIFACT_BUILD_NUMBER_GDA_ | head -1)
build_number=${!copyartifact_variable_name}
if [ -n "${build_number}" ]; then
    echo "set-build-description: testing <a href=\"/job/GDA.${GDA_release}-create.product.beamline-${GDA_group}-${GDA_beamline}/\">create-product</a> build <a href=\"/job/GDA.${GDA_release}-create.product.beamline-${GDA_group}-${GDA_beamline}/${build_number}/\">${build_number}</a>"
fi
