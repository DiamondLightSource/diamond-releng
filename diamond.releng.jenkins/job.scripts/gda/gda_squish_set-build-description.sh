# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/copyartifact_get_build_number.sh

if [ -n "${copyartifact_build_number}" ]; then
    echo "append-build-description: testing <a href=\"/job/${upstream_create_product_job}/\">create-product</a> build <a href=\"/job/${upstream_create_product_job}/${copyartifact_build_number}/\">${copyartifact_build_number}</a>"
fi
