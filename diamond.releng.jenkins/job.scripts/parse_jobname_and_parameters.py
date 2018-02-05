#!/usr/bin/env python

# Parse the Jenkins jobname and extract certain information from it
# Write the information from the jobname into a temporary file in the form of name=value pairs (note: must be simple text values)
# The next step in the Jenkins job is "Inject Environment Variables" which sets the name=value pairs as environment variables for the remainder of the job

from __future__ import absolute_import, division, print_function, unicode_literals
import os
import re
import time
import cStringIO

def parse_jenkins_jobname(jobname):
    parse_result = []  # use a list of tuples rather than a dictionary, so insertion order is maintained (OrderedDict not available pre-Python 2.7)

    if 'download.public' in jobname:
        parse_result.append(('download.public', True))
        parse_result.append(('pewma_py_use_public_version', True))
        parse_result.append(('buckminster_headless_use_public_version', True))
        parse_result.append(('materialize_location_option', '--location=public'))
    else:
        parse_result.append(('download.public', False))

    #########################
    # Parsing for Dawn jobs #
    #########################

    jm = re.match('^Dawn(?P<DAWN_flavour>Diamond|Vanilla)\.(?P<DAWN_release>[^-]+)-.+?(?P<download_public>-download\.public)?(?P<job_variant>~.+)?$', jobname)
    if jm:
        for part in ('DAWN_flavour', 'DAWN_release', 'job_variant'):
            parse_result.append((part, jm.groupdict()[part]))

        # if this is a create.product job, work out the name of the two downstream jobs (the publish.snapshot job, and the squish trigger job)
        if 'create.product' in jobname:
            parse_result.append(('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'))
            parse_result.append(('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'))  # retained for versions prior to Dawn 2.2 / GDA 9.2
            parse_result.append(('build_options_extra', '--suppress-compile-warnings'))
            parse_result.append(('product_options_extra', '--suppress-compile-warnings'))
            parse_result.append(('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'))
            parse_result.append(('publish_snapshot_job_to_trigger', jobname.replace('-create.product', '-publish.snapshot')))
            parse_result.append(('squish_trigger_job_to_trigger', jobname.replace('-create.product', '-squish.trigger')))

        # if this is any publish job, work out the name of the upstream job (the create.product job), and where to publish to
        elif '-publish.' in jobname:
            m = re.match('^(?P<prefix>.+)-publish\.[a-z]+(?P<suffix>.*?)$', jobname)
            parse_result.append(('upstream_create_product_job', m.group('prefix') + '-create.product' + m.group('suffix')))
            # use /dls/science/ (which is not backed up) for snapshot builds, and /dls_sw/apps/ for release builds
            if 'master' in jm.group('DAWN_release'):
                publish_parent = '/dls/science/groups/scisoft/'
            else:
                publish_parent = '/dls_sw/apps/'
            publish_parent = os.path.join(publish_parent,
                                          'Dawn' + jm.group('DAWN_flavour'),
                                          jm.group('DAWN_release') + (jm.group('job_variant') or ''),
                                          '')
            parse_result.append(('publish_module_load_directory_parent', publish_parent))

        # if this is the squish-trigger job, work out the name of the upstream job (the create.product job), and the name structure of the downstream jobs (the squish jobs)
        elif '-squish.trigger' in jobname:
            m = re.match('^(?P<prefix>.+)-squish.trigger(?P<suffix>.*)$', jobname)
            parse_result.append(('upstream_create_product_job',
                                    m.group('prefix') +
                                    '-create.product' +
                                    m.group('suffix') +
                                    (jm.group('job_variant') or '')
                                 ))
            parse_result.append(('squish_platform_job_prefix', m.group('prefix')))
            parse_result.append(('squish_platform_job_suffix', m.group('suffix')))

        # if this is any squish job, work out the name of the upstream job (the create.product job)
        elif '-squish' in jobname:
            m = re.match('^(?P<prefix>.+)-squish(-subset)?(?P<suffix>.+)$', jobname)
            parse_result.append(('upstream_create_product_job',
                                    m.group('prefix')
                                    + '-create.product' +
                                    (jm.group('job_variant') or '')
                                ))

    #########################
    # Parsing for GDA jobs #
    #########################

    jm = re.match('^GDA\.(?P<GDA_release>[^-]+)-(.+?)(?P<download_public>-download\.public)?(?P<job_variant>~.+)?$', jobname)
    if jm:
        for part in ('GDA_release', 'job_variant'):
            parse_result.append((part, jm.groupdict()[part]))
        job_subname = jm.group(2)

        # if this is a gerrit-trigger job, work out the name of the downstream job (the junit.tests-gerrit job)
        if 'gerrit-trigger' in jobname:
            parse_result.append(('gerrit_job_to_trigger', jobname.replace('-gerrit-trigger', '-junit.tests-gerrit')))

        if 'junit' in jobname:
            if 'training' in jobname:
                parse_result.append(('materialize_components', 'training.gerrit.feature'))
            else:
                parse_result.append(('materialize_components', 'all-dls-configs all-dls-clients gdaserver gda-orphan-projects'))

        # GDA create.product.beamline jobs (client)
        # if this is a create.product job, work out the name of the two downstream jobs (the publish.snapshot job, and the squish trigger job)
        m = re.match('^create.product.beamline-(?P<GDA_site>[^-]+)-(?P<GDA_beamline>.+)$', job_subname)
        if m:
            site = m.group('GDA_site')
            beamline = m.group('GDA_beamline')
            parse_result.append(('GDA_beamline', beamline))
            if beamline not in ('logpanel', 'synoptic'):
                config_project = beamline + '-config'
            else:
                config_project = ''
            if site == 'DLS':
                if beamline in ('excalibur', 'synoptic'):
                    product_site = 'uk.ac.gda.client.' + beamline + '.site'
                elif beamline == 'i06-1':
                    product_site = 'uk.ac.gda.beamline.i06_1.site'
                elif beamline == 'i20-1':
                    product_site = 'uk.ac.gda.beamline.i20_1.site'
                elif beamline == 'p45':
                    product_site = 'uk.ac.diamond.daq.beamline.p45.site'
                elif beamline == 'p99':
                    product_site = 'uk.ac.diamond.daq.beamline.p99.site'
                else:
                    product_site = 'uk.ac.gda.beamline.' + beamline + '.site'
            elif site == 'GDA':
                if beamline == 'logpanel':
                    product_site = 'uk.ac.gda.client.' + beamline + '.site'
                else:
                    product_site = 'uk.ac.gda.' + beamline + '.site'
            elif site == 'ESRF':
                product_site = 'fr.esrf.gda.beamline.' + beamline + '.site'
            parse_result.append(('materialize_components', (config_project + ' ' + product_site).strip()))
            parse_result.append(('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'))
            parse_result.append(('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'))  # retained for versions prior to Dawn 2.2 / GDA 9.2
            parse_result.append(('build_options_extra', '--suppress-compile-warnings'))
            parse_result.append(('product_site', product_site))
            parse_result.append(('product_options_extra', '--suppress-compile-warnings'))
            # the example beamline .properties filenames are different from the standard
            if (site == 'GDA') and (beamline == 'example'):
                parse_result.append(('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'))
            else:
                parse_result.append(('buckminster_properties_filename', 'buckminster.jenkins.properties'))
            parse_result.append(('publish_snapshot_job_to_trigger', jobname.replace('-create.product.beamline', '-publish.snapshot')))
            parse_result.append(('squish_trigger_job_to_trigger' ,jobname.replace('-create.product.beamline', '-squish.trigger')))

        # GDA create.product (other than client) jobs
        # if it's a create.product job, but not a create.product.beamline job; or a publish job, get the product name
        else:
            m = re.match('^create.product-(?P<product_name>.+)(?P<download_public>-download\.public)?(?P<job_variant>~.+)?$', job_subname)
            if m:
                product_name = m.group('product_name')
                if product_name == 'gdaserver':
                    materialize_components = 'uk.ac.diamond.daq.server.site'
                    product_site = materialize_components
                elif product_name == 'logpanel':
                    materialize_components = 'uk.ac.gda.client.logpanel.site'
                    product_site = materialize_components
                parse_result.append(('non_beamline_product', product_name))
                parse_result.append(('materialize_components', materialize_components))
                parse_result.append(('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'))
                parse_result.append(('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'))  # retained for versions prior to Dawn 2.2 / GDA 9.2
                parse_result.append(('build_options_extra', '--suppress-compile-warnings'))
                parse_result.append(('product_site', product_site))
                parse_result.append(('product_options_extra', '--suppress-compile-warnings'))
                parse_result.append(('buckminster_properties_filename', 'buckminster.jenkins.properties'))
                parse_result.append(('publish_snapshot_job_to_trigger', jobname.replace('-create.product', '-publish.snapshot')))
                parse_result.append(('squish_trigger_job_to_trigger', jobname.replace('-create.product', '-squish.trigger')))

        # if this is any publish job, work out the name of the upstream job (the create.product job), and where to publish to
        if '-publish.' in jobname:
            m = re.match('^(?P<prefix>.+)-publish.[a-z]+-(?P<product_name>.+)(?P<suffix>.?)$', jobname)
            if m.group('product_name') not in ('gdaserver', 'logpanel'):
                parse_result.append(('upstream_create_product_job', m.group('prefix') + '-create.product.beamline-' + m.group('product_name') + m.group('suffix')))
                directory_product_name = 'gdaclient'
            else:
                parse_result.append(('upstream_create_product_job', m.group('prefix') + '-create.product-' + m.group('product_name') + m.group('suffix')))
                directory_product_name = m.group('product_name')
            # use /dls/science/ (which is not backed up) snapshot builds, and /dls_sw/apps/ for release builds
            if 'master' in jm.group('GDA_release'):
                publish_parent = '/dls/science/groups/daq/'
            else:
                publish_parent = '/dls_sw/apps/'
            publish_parent = os.path.join(publish_parent,
                                          directory_product_name,
                                          jm.group('GDA_release') + (jm.group('job_variant') or ''),
                                          '')
            parse_result.append(('publish_module_load_directory_parent', publish_parent))
            # for GDA, even if we build for non-linux64 platforms, we don't save the build, so don't attempt to publish
            parse_result.append(('platform_windows64', 'false'))
            parse_result.append(('platform_mac64', 'false'))

        # if this is the squish-trigger job, work out the name of the upstream job (the create.product job), and the name structure of the downstream jobs (the squish jobs)
        elif '-squish.trigger' in jobname:
            m = re.match('^(?P<prefix>.+)-squish.trigger(?P<suffix>.*)$', jobname)
            parse_result.append(('upstream_create_product_job', m.group('prefix') + '-create.product' + m.group('suffix')))
            parse_result.append(('squish_platform_job_prefix', m.group('prefix')))
            parse_result.append(('squish_platform_job_suffix', m.group('suffix')))

        # if this is any squish job, work out the name of the upstream job (the create.product job)
        elif '-squish' in jobname:
            m = re.match('^(?P<prefix>.+)-squish(-subset)?(?P<suffix>.+)$', jobname)
            parse_result.append(('upstream_create_product_job', m.group('prefix') + '-create.product' + m.group('suffix')))

    # For JUnit jobs, post-build should scan for compiler warnings, and for open tasks, only in master
    if 'junit' in jobname:
        if 'gerrit' in jobname:
            parse_result.append(('build_options_extra', '--suppress-compile-warnings'))
        if 'gerrit' not in jobname:
            scan = False
            for (k,v) in parse_result:
                if k.endswith('_release') and (v == 'master'):
                    scan = True
                    break
            parse_result.append(('postbuild_scan_for_compiler_warnings', scan))
            parse_result.append(('postbuild_scan_for_open_tasks', scan))

    # determine whether any publish_* parameter was set
    # determine whether any trigger_squish_* parameter was set
    if 'create.product' in jobname:
        at_least_one_publish_parameter_selected = False
        at_least_one_trigger_squish_parameter_selected = False
        for (k, v) in os.environ.iteritems():
            if k.startswith('publish_') and (v.lower() == 'true'):
                at_least_one_publish_parameter_selected = True
            if k.startswith('trigger_squish_') and (v.lower() == 'true'):
                at_least_one_trigger_squish_parameter_selected = True
            if at_least_one_publish_parameter_selected and at_least_one_trigger_squish_parameter_selected:
                break
        parse_result.append(('at_least_one_publish_parameter_selected', at_least_one_publish_parameter_selected))
        parse_result.append(('at_least_one_trigger_squish_parameter_selected', at_least_one_trigger_squish_parameter_selected))

    return parse_result


def write_parse_result(parse_result, output_file=None):
    ''' Writes the parse result to output_file (or stdout), in a format suitable for being consumed by bash
    '''

    print('### File generated ' + time.strftime("%a, %Y/%m/%d %H:%M:%S %z") +
          ' (' + os.environ.get('BUILD_URL','$BUILD_URL:missing') + ')',
          file=output_file)
    for (k,v) in parse_result:
        if v is False:
            v = 'false'  # representation for False in our bash scripts (this is how Jenkins parameters code it)
        elif v is True:
            v = 'true'  # representation for True in our bash scripts (this is how Jenkins parameters code it)
        elif v is None:
            v = ''
        print(k,'=',v, sep='', file=output_file)  # no separator, so that bash interprets the output as set statements for environment variables

def test_parse_jenkins_jobname():
    ''' Test that the parse results are as expected
    '''

    output = cStringIO.StringIO()  # somewhere temporary to write parse output

    # Tests for DAWN release branches
    p = parse_jenkins_jobname('DawnDiamond.1.11-create.product')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', '1.11'),
        ('job_variant', None),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'DawnDiamond.1.11-publish.snapshot'),
        ('squish_trigger_job_to_trigger', 'DawnDiamond.1.11-squish.trigger'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)  # check that we can format the parse result

    p = parse_jenkins_jobname('DawnDiamond.1.11-publish.release')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', '1.11'),
        ('job_variant', None),
        ('upstream_create_product_job', 'DawnDiamond.1.11-create.product'),
        ('publish_module_load_directory_parent', '/dls_sw/apps/DawnDiamond/1.11/'),
        ]
    write_parse_result(p, output)

    # Tests for DAWN 1.master branch
    p = parse_jenkins_jobname('DawnDiamond.1.master-junit.tests')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', '1.master'),
        ('job_variant', None),
        ('postbuild_scan_for_compiler_warnings', False),
        ('postbuild_scan_for_open_tasks', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnDiamond.1.master-create.product')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', '1.master'),
        ('job_variant', None),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'DawnDiamond.1.master-publish.snapshot'),
        ('squish_trigger_job_to_trigger', 'DawnDiamond.1.master-squish.trigger'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnDiamond.1.master-publish.snapshot')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', '1.master'),
        ('job_variant', None),
        ('upstream_create_product_job', 'DawnDiamond.1.master-create.product'),
        ('publish_module_load_directory_parent', '/dls/science/groups/scisoft/DawnDiamond/1.master/'),
        ]
    write_parse_result(p, output)

    # Tests for DAWN master branch
    p = parse_jenkins_jobname('DawnDiamond.master-junit.tests')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', 'master'),
        ('job_variant', None),
        ('postbuild_scan_for_compiler_warnings', True),
        ('postbuild_scan_for_open_tasks', True),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnDiamond.master-create.product')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', 'master'),
        ('job_variant', None),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'DawnDiamond.master-publish.snapshot'),
        ('squish_trigger_job_to_trigger', 'DawnDiamond.master-squish.trigger'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnDiamond.master-publish.snapshot')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', 'master'),
        ('job_variant', None),
        ('upstream_create_product_job', 'DawnDiamond.master-create.product'),
        ('publish_module_load_directory_parent', '/dls/science/groups/scisoft/DawnDiamond/master/'),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnDiamond.master-squish.RedHat6-DLS')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', 'master'),
        ('job_variant', None),
        ('upstream_create_product_job', 'DawnDiamond.master-create.product'),
        ]
    write_parse_result(p, output)

    # Tests for DAWN master branch - DawnVanilla
    p = parse_jenkins_jobname('DawnVanilla.master-create.product-download.public')
    assert p == [
        ('download.public', True),
        ('pewma_py_use_public_version', True),
        ('buckminster_headless_use_public_version', True),
        ('materialize_location_option', '--location=public'),
        ('DAWN_flavour', 'Vanilla'),
        ('DAWN_release', 'master'),
        ('job_variant', None),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'DawnVanilla.master-publish.snapshot-download.public'),
        ('squish_trigger_job_to_trigger', 'DawnVanilla.master-squish.trigger-download.public'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnVanilla.master-publish.snapshot-download.public')
    assert p == [
        ('download.public', True),
        ('pewma_py_use_public_version', True),
        ('buckminster_headless_use_public_version', True),
        ('materialize_location_option', '--location=public'),
        ('DAWN_flavour', 'Vanilla'),
        ('DAWN_release', 'master'),
        ('job_variant', None),
        ('upstream_create_product_job', 'DawnVanilla.master-create.product-download.public'),
        ('publish_module_load_directory_parent', '/dls/science/groups/scisoft/DawnVanilla/master/'),
        ]
    write_parse_result(p, output)

    # Tests for DAWN master branch with ~variant
    p = parse_jenkins_jobname('DawnDiamond.master-junit.tests~neweclipse')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', 'master'),
        ('job_variant', '~neweclipse'),
        ('postbuild_scan_for_compiler_warnings', True),
        ('postbuild_scan_for_open_tasks', True),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnDiamond.master-create.product~neweclipse')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', 'master'),
        ('job_variant', '~neweclipse'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'DawnDiamond.master-publish.snapshot~neweclipse'),
        ('squish_trigger_job_to_trigger', 'DawnDiamond.master-squish.trigger~neweclipse'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('DawnDiamond.master-publish.snapshot~neweclipse')
    assert p == [
        ('download.public', False),
        ('DAWN_flavour', 'Diamond'),
        ('DAWN_release', 'master'),
        ('job_variant', '~neweclipse'),
        ('upstream_create_product_job', 'DawnDiamond.master-create.product~neweclipse'),
        ('publish_module_load_directory_parent', '/dls/science/groups/scisoft/DawnDiamond/master~neweclipse/'),
        ]
    write_parse_result(p, output)

    # Tests for GDA training master branch
    p = parse_jenkins_jobname('GDA.master-training-junit.tests-gerrit')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('materialize_components', 'training.gerrit.feature'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ]
    write_parse_result(p, output)

    # Tests for GDA master branch
    p = parse_jenkins_jobname('GDA.master-gerrit-trigger')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('gerrit_job_to_trigger', 'GDA.master-junit.tests-gerrit'),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('GDA.master-junit.tests')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('materialize_components', 'all-dls-configs all-dls-clients gdaserver gda-orphan-projects'),
        ('postbuild_scan_for_compiler_warnings', True),
        ('postbuild_scan_for_open_tasks', True),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('GDA.master-junit.tests-gerrit')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('materialize_components', 'all-dls-configs all-dls-clients gdaserver gda-orphan-projects'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('GDA.master-create.product.beamline-GDA-example')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('GDA_beamline', 'example'),
        ('materialize_components', 'example-config uk.ac.gda.example.site'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_site', 'uk.ac.gda.example.site'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'GDA.master-publish.snapshot-GDA-example'),
        ('squish_trigger_job_to_trigger', 'GDA.master-squish.trigger-GDA-example'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('GDA.master-create.product.beamline-GDA-example-download.public')
    assert p == [
        ('download.public', True),
        ('pewma_py_use_public_version', True),
        ('buckminster_headless_use_public_version', True),
        ('materialize_location_option', '--location=public'),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('GDA_beamline', 'example'),
        ('materialize_components', 'example-config uk.ac.gda.example.site'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_site', 'uk.ac.gda.example.site'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.diamond.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'GDA.master-publish.snapshot-GDA-example-download.public'),
        ('squish_trigger_job_to_trigger', 'GDA.master-squish.trigger-GDA-example-download.public'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('GDA.master-create.product.beamline-DLS-b16')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('GDA_beamline', 'b16'),
        ('materialize_components', 'b16-config uk.ac.gda.beamline.b16.site'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_site', 'uk.ac.gda.beamline.b16.site'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'GDA.master-publish.snapshot-DLS-b16'),
        ('squish_trigger_job_to_trigger', 'GDA.master-squish.trigger-DLS-b16'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('GDA.master-create.product-gdaserver')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('non_beamline_product', 'gdaserver'),
        ('materialize_components', 'uk.ac.diamond.daq.server.site'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments.common=true'),
        ('materialize_properties_extra', '-Dskip_ALL_test_fragments=true'),
        ('build_options_extra', '--suppress-compile-warnings'),
        ('product_site', 'uk.ac.diamond.daq.server.site'),
        ('product_options_extra', '--suppress-compile-warnings'),
        ('buckminster_properties_filename', 'buckminster.jenkins.properties'),
        ('publish_snapshot_job_to_trigger', 'GDA.master-publish.snapshot-gdaserver'),
        ('squish_trigger_job_to_trigger', 'GDA.master-squish.trigger-gdaserver'),
        ('at_least_one_publish_parameter_selected', False),
        ('at_least_one_trigger_squish_parameter_selected', False),
        ]
    write_parse_result(p, output)

    p = parse_jenkins_jobname('GDA.master-publish.testing-gdaserver')
    assert p == [
        ('download.public', False),
        ('GDA_release', 'master'),
        ('job_variant', None),
        ('upstream_create_product_job', 'GDA.master-create.product-gdaserver'),
        ('publish_module_load_directory_parent', '/dls/science/groups/daq/gdaserver/master/'),
        ('platform_windows64', 'false'),
        ('platform_mac64', 'false'),
        ]
    write_parse_result(p, output)

    output.close()

    print('*** Completed: test_parse_jenkins_jobname()')

if __name__ == '__main__':
    # test_parse_jenkins_jobname()
    p = parse_jenkins_jobname(os.environ['JOB_NAME'])
    write_parse_result(p)

