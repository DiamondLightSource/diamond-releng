# Parse the Jenkins jobname and extra certain information from it
# Write the information from the jobname into a temporary file in the form of name=value pairs
# The next step in the Jenkins job is "Inject Environment Variables" which sets the name=value pairs as environment variables for the remainder of the job
set +x  # Turn off xtrace

properties_filename=${WORKSPACE}/parsed-jobname.properties
rm -f ${properties_filename}

# The jobname must start with "DawnDiamond." or "DawnVanilla.", followed by the release, followed by "-", followed by anything

if [[ "${JOB_NAME:0:12}" == "DawnDiamond." || "${JOB_NAME:0:12}" == "DawnVanilla." ]]; then
    flavour=${JOB_NAME:4:7}
    releasesuffixindex=$(expr index "${JOB_NAME}" '-')
    if [[ "${releasesuffixindex}" != "0" ]]; then
        # -13 is -12 for "Dawn<flavour>." and -1 for "-"
        release=${JOB_NAME:12:${releasesuffixindex}-13}
        result=good
    fi

    if [[ "${JOB_NAME:-noname}" == *download.public ]]; then
        download_public=true
    else
        download_public=false
    fi

    # if this is a create.product job, work out the name of the two downstream jobs (the publish-snapshot job, and the squish trigger job)
    if [[ "${JOB_NAME:-noname}" == *create.product* ]]; then
        publish_snapshot_job_to_trigger=$(echo "${JOB_NAME}" | sed 's/-create.product/--publish.snapshot/')
        squish_trigger_job_to_trigger=$(echo "${JOB_NAME}" | sed 's/-create.product/--squish.trigger/')
    fi
    # if this is any publish job, or the squish-trigger job (nb: not the individual squish jobs), work out the name of the upstream job (the create.product job)
    if [[ "${JOB_NAME:-noname}" == *--squish.trigger* ]]; then
        upstream_product_job=$(echo "${JOB_NAME}" | sed 's/--squish.trigger/-create.product/')
    elif [[ "${JOB_NAME:-noname}" == *--publish-snapshot* ]]; then
        upstream_product_job=$(echo "${JOB_NAME}" | sed 's/--publish-snapshot/-create.product/')
    elif [[ "${JOB_NAME:-noname}" == *--publish-beta* ]]; then
        upstream_product_job=$(echo "${JOB_NAME}" | sed 's/--publish-beta/-create.product/')
    elif [[ "${JOB_NAME:-noname}" == *--publish-stable* ]]; then
        upstream_product_job=$(echo "${JOB_NAME}" | sed 's/--publish-stable/-create.product/')
    fi

    if [[ "${JOB_NAME:-noname}" =~ ^Dawn.+--publish-([a-z0-9]+)$ ]]; then
        publish_type=${BASH_REMATCH[1]}
    fi
    if [[ "${JOB_NAME:-noname}" =~ ^Dawn.+--publish-([a-z0-9]+)\.cleanup$ ]]; then
        cleanup_type=${BASH_REMATCH[1]}
    fi

fi

echo "Dawn_flavour=${flavour:Error}" >> ${properties_filename}
echo "Dawn_release=${release:Error}" >> ${properties_filename}
echo "download_public=${download_public:Error}" >> ${properties_filename}
if [[ -n "${publish_snapshot_job_to_trigger}" ]]; then
    echo "DAWN_publish_snapshot_job_to_trigger=${publish_snapshot_job_to_trigger}" >> ${properties_filename}
fi
if [[ -n "${squish_trigger_job_to_trigger}" ]]; then
    echo "DAWN_squish_trigger_job_to_trigger=${squish_trigger_job_to_trigger}" >> ${properties_filename}
fi
if [[ -n "${upstream_product_job}" ]]; then
    echo "DAWN_upstream_product_job=${upstream_product_job}" >> ${properties_filename}
fi
if [[ -n "${publish_type}" ]]; then
    echo "publish_type=${publish_type}" >> ${properties_filename}
fi
if [[ -n "${cleanup_type}" ]]; then
    echo "cleanup_type=${cleanup_type}" >> ${properties_filename}
fi
if [[ "${result:bad}" != "good" ]]; then
    echo "Error parsing \${JOB_NAME}=${JOB_NAME}"
    exit 2
fi

echo "[dawn_parse-jobname.sh] wrote ${properties_filename} --->"
cat ${properties_filename}

