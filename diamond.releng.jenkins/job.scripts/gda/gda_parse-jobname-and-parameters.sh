# Parse the Jenkins jobname and extract certain information from it
# Write the information from the jobname into a temporary file in the form of name=value pairs (note: must be simple text values)
# The next step in the Jenkins job is "Inject Environment Variables" which sets the name=value pairs as environment variables for the remainder of the job
set +x  # Turn off xtrace

properties_filename=${WORKSPACE}/parsed-jobname-and-parameters.properties
rm -fv ${properties_filename}
echo "# Written `date +"%a %d/%b/%Y %H:%M:%S %z"` (${BUILD_URL:-\$BUILD_URL:missing})" >> ${properties_filename}

# The jobname must start with "GDA.", followed by the release (e.g. master, 8.42), followed by a dash (-)
# IF the jobname contains "create.product.beamline-<SITE>-", it must be followed by <beamline name> (which may contain a -), optionally followed by -download.public
# OTHERWISE site and beamline do not apply
# optionally terminated by "~" and a variant name (something like "~e4")

if [[ "${JOB_NAME:0:4}" == "GDA." ]]; then
    releasesuffixindex=$(expr index "${JOB_NAME}" '-')
    if [[ "${releasesuffixindex}" != "0" ]]; then
        # -5 is -4 for "GDA." and -1 for "-"
        release=${JOB_NAME:4:${releasesuffixindex}-5}
    fi
fi
if [[ -z "${release}" ]]; then
    echo "Error parsing \${JOB_NAME}=${JOB_NAME}"
    exit 2
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

# if this is a gerrit-trigger job, work out the name of the downstream job (the junit.tests-gerrit job)
if [[ "${JOB_NAME:-noname}" == *-gerrit-trigger* ]]; then
    gerrit_job_to_trigger=$(echo "${JOB_NAME}" | sed 's/-gerrit-trigger/-junit.tests-gerrit/')
fi

sitebeamlinesuffixindex=$(expr match "${JOB_NAME:-noname}" 'GDA\..*beamline-')
if [[ "${sitebeamlinesuffixindex}" != "0" ]]; then
    sitebeamlinesuffix=${JOB_NAME:sitebeamlinesuffixindex}
    dash=$(expr index ${sitebeamlinesuffix} '-') || true
    if [[ "${dash}" != "0" ]]; then
        site=${sitebeamlinesuffix:0:${dash}-1}
        beamlinesuffix=${sitebeamlinesuffix:${dash}}
        beamline=${beamlinesuffix%%-download.public}
        # if this is a create.product job, work out the name of the downstream job (the squish job)
        if [[ "${JOB_NAME:-noname}" == *-create.product.beamline* ]]; then
            squish_job_to_trigger=$(echo "${JOB_NAME}" | sed 's/-create.product.beamline/-squish.beamline/')
        fi
        # if this is a squish job, work out the name of the upstream job (the create.product job)
        if [[ "${JOB_NAME:-noname}" == *-squish.beamline* ]]; then
            upstream_product_job=$(echo "${JOB_NAME}" | sed 's/-squish.beamline/-create.product.beamline/')
        fi
    fi
else
    # if it's a create.product job, but not a create.product.beamline job, get the product name
    createproductsuffixindex=$(expr match "${JOB_NAME:-noname}" 'GDA\..*create.product-')
    if [[ "${createproductsuffixindex}" != "0" ]]; then
        createproductsuffix=${JOB_NAME:createproductsuffixindex}
        dash=$(expr index ${createproductsuffix} '-') || true
        if [[ "${dash}" != "0" ]]; then
            nonbeamlineproduct=${createproductsuffix:0:${dash}-1}
        else
            nonbeamlineproduct=${createproductsuffix}
        fi
    fi
fi

# only for selected jobs (junit) and releases (master), the post-build should scan for compiler warnings, and for open tasks
if [[ "${JOB_NAME:-noname}" == *junit* ]]; then
    if [[ "${JOB_NAME:-noname}" != *gerrit* && "${release}" == "master" ]]; then
        postbuild_scan_for_compiler_warnings=true
        postbuild_scan_for_open_tasks=true
    else
        postbuild_scan_for_compiler_warnings=false
        postbuild_scan_for_open_tasks=false
    fi
fi

echo "download_public=${download_public:Error}" >> ${properties_filename}
echo "GDA_release=${release:Error}" >> ${properties_filename}
echo "GDA_job_variant=${job_variant:Error}" >> ${properties_filename}

if [[ -n "${site}" ]]; then
    echo "beamline_site=${site}" >> ${properties_filename}
fi
if [[ -n "${beamline}" ]]; then
    echo "GDA_beamline=${beamline}" >> ${properties_filename}
fi
if [[ -n "${nonbeamlineproduct}" ]]; then
    echo "non_beamline_product=${nonbeamlineproduct}" >> ${properties_filename}
fi
if [[ -n "${squish_job_to_trigger}" ]]; then
    echo "GDA_squish_job_to_trigger=${squish_job_to_trigger}" >> ${properties_filename}
fi
if [[ -n "${gerrit_job_to_trigger}" ]]; then
    echo "GDA_gerrit_job_to_trigger=${gerrit_job_to_trigger}" >> ${properties_filename}
fi
if [[ -n "${upstream_product_job}" ]]; then
    echo "GDA_upstream_product_job=${upstream_product_job}" >> ${properties_filename}
fi
if [[ -n "${postbuild_scan_for_compiler_warnings}" ]]; then
    echo "postbuild_scan_for_compiler_warnings=${postbuild_scan_for_compiler_warnings}" >> ${properties_filename}
fi
if [[ -n "${postbuild_scan_for_open_tasks}" ]]; then
    echo "postbuild_scan_for_open_tasks=${postbuild_scan_for_open_tasks}" >> ${properties_filename}
fi

echo "[gda_parse-jobname-and-parameters.sh] wrote ${properties_filename} --->"
cat ${properties_filename}

