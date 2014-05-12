platform_count=$( (set -o posix ; set) | grep "trigger_" | grep "true" | wc -l)
if [ -n "${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT}" ]; then
    echo "set-build-description: testing <a href=\"/job/DawnDiamond.master-create.product/\">create-product</a> build <a href=\"/job/DawnDiamond.master-create.product/${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT}/\">${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT}</a> for ${platform_count} platforms"
elif [ -n "${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT_JAVA_}" ]; then
    echo "set-build-description: testing <a href=\"/job/DawnDiamond.master-create.product.Java7/\">create-product.Java7</a> build <a href=\"/job/DawnDiamond.master-create.product.Java7/${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT_JAVA_}/\">${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT_JAVA_}</a> for ${platform_count} platforms"
elif [ -n "${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT_ECLIPSE_}" ]; then
    echo "set-build-description: testing <a href=\"/job/DawnDiamond.master-create.product.Eclipse38/\">create-product.Eclipse38</a> build <a href=\"/job/DawnDiamond.master-create.product.Eclipse38/${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT_ECLIPSE_}/\">${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT_ECLIPSE_}</a> for ${platform_count} platforms"
fi
