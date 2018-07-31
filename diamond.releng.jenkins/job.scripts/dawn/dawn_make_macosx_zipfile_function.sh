# Make a proper zipped macOS app bundle out of the dumpster fire produced by Jenkins
# Mostly based on the instructions at https://confluence.diamond.ac.uk/display/SCI/Build+macOS+product+manually+in+IDE

#------------------------------------#
#------------------------------------#

dawn_make_macosx_zipfile_function () {

    # Save xtrace state (1=was not set, 0=was set)
    if [[ $- = *x* ]]; then
        oldxtrace=0
    else
        oldxtrace=1
    fi
    set +x  # Turn off xtrace

    # Save errexit state (1=was not set, 0=was set)
    if [[ $- = *e* ]]; then
        olderrexit=0
    else
        olderrexit=1
    fi
    set -e  # Turn on errexit

    ###
    ### Turn the product into a MacOSX installer
    ###

    cd ${buckminster_root_prefix}/products/
    for buildname in $(shopt -s nullglob; echo DawnDiamond-*-mac64); do
        # delete the zip of the exported macOSX product (if it exists), this is useless. We'll replace it with a proper installable file.
        rm -fv ${buildname}.zip

        mv ${buildname}/* Dawn.app/Contents
        mkdir Dawn.app/Contents/Eclipse
        mv Dawn.app/Contents/Dawn.ini Dawn.app/Contents/Eclipse
        sed -i -e "s/$buildname\///" Dawn.app/Contents/Eclipse/Dawn.ini
        chmod a+x Dawn.app/Contents/MacOS/Dawn
        patch -p1 < /dls_sw/dasc/macOSZipfile/Info.plist.patch
        sed --in-place "s#<<AppVersion>>#${product_version_number}#" Dawn.app/Contents/Info.plist
        mkdir Dawn.app/Contents/Resources
        cp -v /dls_sw/dasc/macOSZipfile/Dawn.icns Dawn.app/Contents/Resources
        cp -a /dls_sw/dasc/macOSZipfile/jre Dawn.app/Contents/jre

        zip -ry ${buildname}.zip Dawn.app
    done

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#



