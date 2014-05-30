import os

set_build_description_done = False
try:
    for (publish_job, product_build_job, product_build_job_short, build_name_copied_var) in (
        ('DawnDiamond.gda830--publish', 'DawnDiamond.gda830-create.product', 'gda830-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_GDA_CREATE_PRODUCT'),
        ('DawnDiamond.gda832--publish', 'DawnDiamond.gda832-create.product', 'gda832-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_GDA_CREATE_PRODUCT'),
        ('DawnDiamond.gda834--publish', 'DawnDiamond.gda834-create.product', 'gda834-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_GDA_CREATE_PRODUCT'),
        ('DawnDiamond.gda836--publish', 'DawnDiamond.gda836-create.product', 'gda836-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_GDA_CREATE_PRODUCT'),
        ('DawnDiamond.gda838--publish', 'DawnDiamond.gda838-create.product', 'gda838-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_GDA_CREATE_PRODUCT'),
        ('DawnDiamond.gda840--publish', 'DawnDiamond.gda840-create.product', 'gda840-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_GDA_CREATE_PRODUCT'),
        ('DawnDiamond.1.4.1--publish', 'DawnDiamond.1.4.1-create.product', '1.4.1-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_CREATE_PRODUCT'),
        ('DawnDiamond.master--publish', 'DawnDiamond.master-create.product', 'DawnDiamond-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNDIAMOND_MASTER_CREATE_PRODUCT'),
        ('DawnVanilla.master--publish', 'DawnVanilla.master-create.product-download.public', 'DawnVanilla-create.product', 'COPYARTIFACT_BUILD_NUMBER_DAWNVANILLA_MASTER_CREATE_PRODUCT_DOWNLOAD_PUBLIC'),
        ):
        if os.environ['JOB_NAME'].lower().startswith(publish_job.lower()):
            product_build_number = os.environ[build_name_copied_var]
            build_description_line_1 = os.environ['product_version_number']
            build_description_line_1 += r'  (x%(platform_count)s) (<a href="/job/%(product_build_job)s/">%(product_build_job_short)s</a> <a href="/job/%(product_build_job)s/%(product_build_number)s/">%(product_build_number)s</a>)' % \
                {'product_build_job': product_build_job, 'product_build_job_short': product_build_job_short, 'product_build_number': product_build_number, 'platform_count': os.environ['platforms_requested']}
            build_description_line_2 = ''
            if os.environ['publish_module_load'] == 'true':
                build_description_line_2 += r', module load'
            if os.environ['publish_webserver_diamond_zip'] == 'true':
                build_description_line_2 += r', diamond .zip'
            if os.environ['publish_webserver_opengda_zip'] == 'true':
                build_description_line_2 += r', opengda .zip'
            if os.environ['publish_p2_site'] == 'true':
                build_description_line_2 += r', p2 site'
            if build_description_line_2:
                print 'set-build-description: %s --> %s' % (build_description_line_1, build_description_line_2[2:])
            else:
                print 'set-build-description: %s (not published anywhere)' % (build_description_line_1,)
            set_build_description_done = True
            break

except Exception as fault:
    print os.path.basename(__file__), 'got exception:', fault

if not set_build_description_done:
    print 'set-build-description: internal error: publish details not determined'
