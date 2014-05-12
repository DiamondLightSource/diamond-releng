# Helper functions

############################################
### Copy control scripts from Host to VM ###
############################################
copy_control() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` copy_control"
    rm -f ${VMHOST_TMP}/squish_control.zip
    (cd ${SQUISH_CONTROL_DIR} && zip -r ${VMHOST_TMP}/squish_control.zip .)
    vmcopy_host_to_guest ${VMHOST_TMP}/squish_control.zip "${VMGUEST_SCRATCH}/squish_control.zip"
    }

###################################
### Copy Squish from Host to VM ###
###################################
copy_squish() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` copy_squish"
    squish_zip=squish_${VMOSTYPE}_zip
    vmcopy_host_to_guest ${!squish_zip} "${VMGUEST_SCRATCH}/squish.zip"
    }

################################
### Copy JRE from Host to VM ###
################################
copy_jre() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` copy_jre"
    # the JRE installer has a suffix of .bin on Linux, and .exe on Windows
    jre_installer=jre_${VMOSTYPE}_installer
    jre_filename=$(basename "$(readlink -en ${!jre_installer})")
    jre_extension="${jre_filename##*.}"
    vmcopy_host_to_guest ${!jre_installer} "${VMGUEST_SCRATCH}/jre.${jre_extension}"
    }

#####################################
### Copy EPD Free from Host to VM ###
#####################################
copy_epd_free() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` copy_epd_free"
    # the EPD installer has a suffix of .sh on Linux, and .msi on Windows
    epd_free_installer=epd_free_${VMOSTYPE}_installer
    epd_free_filename=$(basename "$(readlink -en ${!epd_free_installer})")
    epd_free_extension="${epd_free_filename##*.}"
    vmcopy_host_to_guest ${!epd_free_installer} "${VMGUEST_SCRATCH}/epd_free.${epd_free_extension}"
    }

##########################################
### Test if application includes a JRE ###
##########################################
function application_zip_includes_jre() {
    # handle the case when either the application is at the top level in the zip, or is inside a single directory in the zip
    return zipinfo -1 ${SQUISH_AUT_ZIP} jre/bin/ || zipinfo -1 ${SQUISH_AUT_ZIP} "*/jre/bin/" -x "*/*/jre/bin/"
    }

########################################
### Copy application from Host to VM ###
########################################
copy_application() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` copy_application"
    vmcopy_host_to_guest $SQUISH_AUT_ZIP "${VMGUEST_SCRATCH}/aut.zip"
    }

##################################
### Copy tests from Host to VM ###
##################################
copy_tests() {
    echo "`date +"%a %d/%b/%Y %H:%M:%S"` copy_tests"
    vmcopy_host_to_guest ${SQUISH_TESTDIR_ZIP_IN} "${VMGUEST_SCRATCH}/squish_tests.zip"
    }
