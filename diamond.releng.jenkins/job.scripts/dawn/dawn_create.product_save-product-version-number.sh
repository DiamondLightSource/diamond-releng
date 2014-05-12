for product in $(find ${buckminster_root_prefix}/products/ -mindepth 1 -maxdepth 1 -type d ! -name '*.zip' ! -name '*squish*' -name 'Dawn*.v[0-9]*' | xargs -i basename {} | sort); do 
    # get the first product, and extract the version number from the directory name, which looks something like DawnDiamond-1.3.0.v20130830-1323-linux32
    version=$(echo "${product}" | sed -ne 's/^Dawn[^-]*-\(.\+\)-[[:alnum:]]\+$/\1/p')
    if [[ -n "${version}" ]]; then
        export product_version_number=${version}
        break
    fi
    export product_version_number="(version unknown)"
done
echo "${product_version_number}" > ${buckminster_root_prefix}/products/product_version_number.txt
echo "\"${product_version_number}\" written to ${buckminster_root_prefix}/products/product_version_number.txt"