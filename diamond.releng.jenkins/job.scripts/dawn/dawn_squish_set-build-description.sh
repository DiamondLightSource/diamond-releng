# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/copyartifact_get_build_number.sh

if [ -n "${copyartifact_build_number}" ]; then
    echo "set-build-description: testing <a href=\"/job/Dawn${Dawn_flavour}.${Dawn_release}-create.product/\">create-product</a> build <a href=\"/job/Dawn${Dawn_flavour}.${Dawn_release}-create.product/${copyartifact_build_number}/\">${copyartifact_build_number}</a> for ${platform_count} platforms"
fi
