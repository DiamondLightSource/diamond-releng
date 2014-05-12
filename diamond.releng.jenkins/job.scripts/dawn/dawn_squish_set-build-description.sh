if [ -n "${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT}" ]; then
    echo "set-build-description: testing <a href=\"/job/DawnDiamond.master-create.product/\">create-product</a> build <a href=\"/job/DawnDiamond.master-create.product/${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT}/\">${COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT}</a>"
elif [ -n "${COPYARTIFACT_BUILD_NUMBER_DAWNVANILLA_MASTER_CREATE_PRODUCT_DOWNLOAD_PUBLIC_}" ]; then
    echo "set-build-description: testing <a href=\"/job/DawnVanilla.master-create.product-download.public/\">create-product-download.public</a> build <a href=\"/job/DawnVanilla.master-create.product/${COPYARTIFACT_BUILD_NUMBER_DAWNVANILLA_MASTER_CREATE_PRODUCT_DOWNLOAD_PUBLIC}/\">${COPYARTIFACT_BUILD_NUMBER_DAWNVANILLA_MASTER_CREATE_PRODUCT_DOWNLOAD_PUBLIC}</a>"
fi
