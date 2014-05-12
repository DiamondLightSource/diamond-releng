for product in $(find ${buckminster_root_prefix}/products/ -mindepth 1 -maxdepth 1 -type d ! -name '*.zip' ! -name '*squish*' -name 'GDA*.v[0-9]*' | xargs -i basename {} | sort); do 
    # get the first product, and extract the version number from the directory name, which looks something like GDA-example-8.38.0.v20140312-1553-linux64
    version=$(echo "${product}" | sed -ne 's/^GDA-.*-\([[:digit:]]\..\+\)-[[:alnum:]]\+$/\1/p')
    if [[ -n "${version}" ]]; then
        export product_version_number=${version}
        break
    fi
    export product_version_number="(version unknown)"
done
echo "${product_version_number}" > ${buckminster_root_prefix}/products/product_version_number.txt
echo "\"${product_version_number}\" written to ${buckminster_root_prefix}/products/product_version_number.txt"