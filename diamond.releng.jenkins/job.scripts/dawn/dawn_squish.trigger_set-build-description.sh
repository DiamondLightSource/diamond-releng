# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/copyartifact_get_build_number.sh

platform_count=$( (set -o posix ; set) | grep "trigger_squish" | grep -v "at_least_one_trigger_squish_parameter_selected" | grep "true" | wc -l)

if [ -n "${copyartifact_build_number}" ]; then
    echo "append-build-description: triggering ${platform_count} test jobs of <a href=\"/job/${DAWN_upstream_product_job}/\">create-product${Dawn_squish_platform_job_suffix}</a> build <a href=\"/job/${DAWN_upstream_product_job}/${copyartifact_build_number}/\">${copyartifact_build_number}</a>"
fi
