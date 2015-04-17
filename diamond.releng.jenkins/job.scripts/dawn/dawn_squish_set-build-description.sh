# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/copyartifact_get_build_number.sh

if [[ "${product_origin}" == *Upload a .zip file* ]]; then
    echo "set-build-description: testing uploaded product .zip"
elif [[ "${product_origin}" == *already on the test machine* ]]; then
    echo "set-build-description: testing product .zip already on the test machine"
elif [ -n "${copyartifact_build_number}" ]; then
    echo "set-build-description: testing <a href=\"/job/${DAWN_upstream_product_job}/\">create-product</a> build <a href=\"/job/${DAWN_upstream_product_job}/${copyartifact_build_number}/\">${copyartifact_build_number}</a>"
else
    echo "set-build-description: Internal error: could not determine what was tested"
fi
