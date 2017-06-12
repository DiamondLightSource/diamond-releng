# Takes the zipped Windows install, and uses InnoSetup running under "wine" to create a proper Windows installer

#------------------------------------#
#------------------------------------#

dawn_make_windows_installer_function () {

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
    ### Turn the product into a Windows installer
    ###

    cd ${buckminster_root_prefix}/products/
    for pdir in DawnDiamond-*-windows64; do
        # write product version number into installer script
        cd /dls_sw/dasc/WindowsInstaller/DawnDiamond-scripts/
        rm -vf DawnWindowsInstaller.iss
        cp -v DawnWindowsInstaller.iss.template DawnWindowsInstaller.iss
        sed --in-place "s#<<AppName>>#Dawn${DAWN_flavour}#" DawnWindowsInstaller.iss
        sed --in-place "s#<<AppVersion>>#${product_version_number}#" DawnWindowsInstaller.iss
        # point to the product to turn into an installer
        cd /dls_sw/dasc/WindowsInstaller/DawnDiamond-scripts/
        rm -vf DawnProduct
        ln -s ${buckminster_root_prefix}/products/${pdir} DawnProduct
        # create the installer
        cd /dls_sw/dasc/WindowsInstaller/DawnDiamond-scripts/
        rm -rf build
        export WINEPREFIX=/dls_sw/dasc/WindowsInstaller/.wine-DawnDiamond/
        ./iscc DawnWindowsInstaller.iss
        # copy installer we just built to directory to be saved
        cp -pv /dls_sw/dasc/WindowsInstaller/DawnDiamond-scripts/build/Dawn${DAWN_flavour}*.exe ${buckminster_root_prefix}/products/
    done

    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
    $([ "$oldxtrace" == "0" ]) && set -x || true  # Turn xtrace on if it was on at the top of this script
    $([ "$oldxtrace" == "1" ]) && set +x || true  # Turn xtrace off if it was off at the top of this script

}

#------------------------------------#
#------------------------------------#

