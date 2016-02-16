# Parse the Jenkins jobname and extract certain information from it
# Write the information from the jobname into a temporary file in the form of name=value pairs
# The next step in the Jenkins job is "Inject Environment Variables" which sets the name=value pairs as environment variables for the remainder of the job
set +x  # Turn off xtrace

properties_filename=${WORKSPACE}/parsed-jobname-and-parameters.properties
rm -fv ${properties_filename}
echo "# Written `date +"%a %d/%b/%Y %H:%M:%S %z"` (${BUILD_URL:-\$BUILD_URL:missing})" >> ${properties_filename}

# The jobname must start with "DawnDiamond." or "DawnVanilla.",
# followed by the release, followed by "-" (something like "master-" or "1.8-")
# followed by anything
# optionally terminated by "~" and a variant name (something like "~e4")

if [[ "${JOB_NAME:0:12}" == "DawnDiamond." || "${JOB_NAME:0:12}" == "DawnVanilla." ]]; then
    flavour=${JOB_NAME:4:7}
    releasesuffixindex=$(expr index "${JOB_NAME}" '-')
    if [[ "${releasesuffixindex}" != "0" ]]; then
        # -13 is -12 for "Dawn<flavour>." and -1 for "-"
        release=${JOB_NAME:12:${releasesuffixindex}-13}
    fi
fi
if [[ -z "${flavour}" || -z "${release}" ]]; then
    echo "Error parsing \${JOB_NAME}=${JOB_NAME}"
    exit 2
fi

# only for selected jobs (DawnDiamond junit) and releases (master), the post-build should scan for compiler warnings, and for open tasks
if [[ "${JOB_NAME:-noname}" == *junit* ]]; then
    if [[ "${JOB_NAME:-noname}" == *DawnDiamond* && "${JOB_NAME:-noname}" != *gerrit* && "${release}" == "master" ]]; then
        postbuild_scan_for_compiler_warnings=true
        postbuild_scan_for_open_tasks=true
    else
        postbuild_scan_for_compiler_warnings=false
        postbuild_scan_for_open_tasks=false
    fi
fi

if [[ "${JOB_NAME:-noname}" == *~* ]]; then
    job_variant=$(echo "${JOB_NAME}" | sed 's/^.*~/~/')
else
    job_variant=
fi

if [[ "${JOB_NAME:-noname}" == *download.public* ]]; then
    download_public=true
else
    download_public=false
fi

# if this is a create.product job, work out the name of the two downstream jobs (the publish.snapshot job, and the squish trigger job)
if [[ "${JOB_NAME:-noname}" == *create.product* ]]; then
    publish_snapshot_job_to_trigger=$(echo "${JOB_NAME}" | sed 's/-create.product/-publish.snapshot/')
    squish_trigger_job_to_trigger=$(echo "${JOB_NAME}" | sed 's/-create.product/-squish.trigger/')

# if this is any publish job, work out the name of the upstream job (the create.product job)
elif [[ "${JOB_NAME:-noname}" == *-publish* ]]; then
    upstream_create_product_job=$(echo "${JOB_NAME}" | sed 's/-publish[^~]*-download.public\(.*\)/-create.product-download.public\1/')
    upstream_create_product_job=$(echo "${upstream_create_product_job}" | sed 's/-publish[^~]*/-create.product/')

# if this is the squish-trigger job, work out the name of the upstream job (the create.product job), and the name structure of the downstream jobs (the squish jobs)
elif [[ "${JOB_NAME:-noname}" == *-squish.trigger* ]]; then
    upstream_create_product_job=$(echo "${JOB_NAME}" | sed 's/-squish.trigger/-create.product/')
    squish_platform_job_prefix=$(echo "${JOB_NAME}" | sed 's/-squish.trigger.*$/-squish./')
    squish_platform_job_suffix=$(echo "${JOB_NAME}" | sed 's/^.*-squish.trigger//')

# if this is any squish job, work out the name of the upstream job (the create.product job)
elif [[ "${JOB_NAME:-noname}" == *-squish-subset.* ]]; then
    upstream_create_product_job=$(echo "${JOB_NAME}" | sed 's/-squish-subset.[^~]*-download.public\(.*\)/-create.product-download.public\1/')
    upstream_create_product_job=$(echo "${upstream_create_product_job}" | sed 's/-squish-subset.[^~]*/-create.product/')
    
elif [[ "${JOB_NAME:-noname}" == *-squish.* ]]; then
    upstream_create_product_job=$(echo "${JOB_NAME}" | sed 's/-squish.[^~]*-download.public\(.*\)/-create.product-download.public\1/')
    upstream_create_product_job=$(echo "${upstream_create_product_job}" | sed 's/-squish.[^~]*/-create.product/')
    echo $upstream_create_product_job
fi

echo "download_public=${download_public:Error}" >> ${properties_filename}
echo "DAWN_flavour=${flavour:Error}" >> ${properties_filename}
echo "DAWN_release=${release:Error}" >> ${properties_filename}
echo "job_variant=${job_variant:Error}" >> ${properties_filename}
if [[ -n "${publish_snapshot_job_to_trigger}" ]]; then
    echo "publish_snapshot_job_to_trigger=${publish_snapshot_job_to_trigger}" >> ${properties_filename}
fi
if [[ -n "${squish_trigger_job_to_trigger}" ]]; then
    echo "squish_trigger_job_to_trigger=${squish_trigger_job_to_trigger}" >> ${properties_filename}
fi
if [[ -n "${upstream_create_product_job}" ]]; then
    echo "upstream_create_product_job=${upstream_create_product_job}" >> ${properties_filename}
fi
if [[ -n "${squish_platform_job_prefix}" ]]; then
    echo "squish_platform_job_prefix=${squish_platform_job_prefix}" >> ${properties_filename}
    echo "squish_platform_job_suffix=${squish_platform_job_suffix}" >> ${properties_filename}
fi

# determine whether any publish_* parameter was set
at_least_one_publish_parameter_selected=false
for var in $(compgen -A variable publish_); do
    if [[ "${!var:false}" == "true" ]]; then
        at_least_one_publish_parameter_selected=true
    fi
done
echo "at_least_one_publish_parameter_selected=${at_least_one_publish_parameter_selected}" >> ${properties_filename}

# determine whether any trigger_squish_* parameter was set
at_least_one_trigger_squish_parameter_selected=false
for var in $(compgen -A variable trigger_squish_); do
    if [[ "${!var:false}" == "true" ]]; then
        at_least_one_trigger_squish_parameter_selected=true
    fi
done
echo "at_least_one_trigger_squish_parameter_selected=${at_least_one_trigger_squish_parameter_selected}" >> ${properties_filename}
if [[ -n "${postbuild_scan_for_compiler_warnings}" ]]; then
    echo "postbuild_scan_for_compiler_warnings=${postbuild_scan_for_compiler_warnings}" >> ${properties_filename}
fi
if [[ -n "${postbuild_scan_for_open_tasks}" ]]; then
    echo "postbuild_scan_for_open_tasks=${postbuild_scan_for_open_tasks}" >> ${properties_filename}
fi

echo "[dawn_parse-jobname-and-parameters.sh] wrote ${properties_filename} --->"
cat ${properties_filename}

