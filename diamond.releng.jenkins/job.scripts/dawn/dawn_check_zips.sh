# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh

# need at least python 2.7
pattern_to_check='Dawn*-linux*.zip'
count_to_check=$(find ${buckminster_root_prefix}/products/ -name "${pattern_to_check}" | wc -l)
if [ "${count_to_check}" != "0" ]; then
    /dls_sw/apps/DataDispenser/python/current-RH6/bin/python ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_check_zip_structure.py --dir MUST_HAVE --jre MUST_HAVE ${buckminster_root_prefix}/products/${pattern_to_check}
else
    echo "No ${buckminster_root_prefix}/products/${pattern_to_check} exist for dawn_check_zip_structure"
fi

pattern_to_check='Dawn*-windows*.zip'
count_to_check=$(find ${buckminster_root_prefix}/products/ -name "${pattern_to_check}" | wc -l)
if [ "${count_to_check}" != "0" ]; then
    /dls_sw/apps/DataDispenser/python/current-RH6/bin/python ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/dawn/dawn_check_zip_structure.py --dir MUST_NOT_HAVE --jre MUST_HAVE ${buckminster_root_prefix}/products/${pattern_to_check}
else
    echo "No ${buckminster_root_prefix}/products/${pattern_to_check} exist for dawn_check_zip_structure"
fi
