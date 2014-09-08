#!/usr/bin/env python

###
### platform-independent script to manage development of Dawn (GDA, SciSoft, IDA)
###

import datetime
import fnmatch
import logging
import optparse
import os
import platform
import re
import socket
import subprocess
import sys
import time
import urllib
import zipfile

COMPONENT_ABBREVIATIONS = [] # tuples of (abbreviation, category, actual component name to use)

for gda_config in (
    'example',                                          # GDA example
    'id18',                                             # APS
    'bm26', 'bm26a',                                    # Dubble at ESRF
    'lpd',                                              # Rutherford
    'all-dls', 'all-mt', 'all-mx',                      # Diamond
    'b16', 'b18', 'b21', 'b23', 'b24', 'dls', 'excalibur',
    'i02', 'i03', 'i04', 'i04-1', 'i05', 'i06', 'i07', 'i08', 'i09',
    'i10', 'i11', 'i11-1', 'i12', 'i13i', 'i13j', 'i15', 'i16', 'i18',
    'i19', 'i20', 'i20-1', 'i22', 'i23', 'i24', 'lab11', 'mt', 'mx', 'ncdsim'):
    COMPONENT_ABBREVIATIONS.append((gda_config, 'gda', gda_config+'-config'))  # recognise name without -config suffix
    COMPONENT_ABBREVIATIONS.append((gda_config+'-config', 'gda', gda_config+'-config'))  # recognise name with -config suffix

for gda_config in ():
    COMPONENT_ABBREVIATIONS.append((gda_config, 'gda', 'uk.ac.gda.beamline.' + gda_config + '.site'))  # no config project for these beamlines
COMPONENT_ABBREVIATIONS.append(('gda-training', 'gda-training', 'gda-training-config'))
COMPONENT_ABBREVIATIONS.append(('sda', 'sda', 'uk.ac.diamond.sda.site'))
COMPONENT_ABBREVIATIONS.append(('dsx', 'ida', 'uk.ac.diamond.dsx.site'))
COMPONENT_ABBREVIATIONS.append(('wychwood', 'ida', 'uk.ac.diamond.dsx.site'))
COMPONENT_ABBREVIATIONS.append(('idabuilder', 'ida', 'uk.ac.diamond.ida.product.site'))
COMPONENT_ABBREVIATIONS.append(('idareport', 'ida', 'uk.ac.diamond.ida.report.site'))
COMPONENT_ABBREVIATIONS.append(('dawnvanilla', 'dawn', 'org.dawnsci.base.site'))
COMPONENT_ABBREVIATIONS.append(('dawndiamond', 'dawn', 'uk.ac.diamond.dawn.site'))
COMPONENT_ABBREVIATIONS.append(('testfiles', 'gda', 'GDALargeTestFiles'))

COMPONENT_CATEGORIES = (
    # category, version, CQuery, template_version, version_synonyms
    ('gda', 'master', 'gda-master.cquery', 'v2.7', ('master', 'trunk')),
    ('gda', 'v8.42', 'gda-v8.42.cquery', 'v2.6', ('v8.42', '8.42', '842')),
    ('gda', 'v8.40', 'gda-v8.40.cquery', 'v2.6', ('v8.40', '8.40', '840')),
    ('gda', 'v8.39', 'gda-v8.39.cquery', 'v2.6', ('v8.39', '8.39', '839')),
    ('gda', 'v8.38', 'gda-v8.38.cquery', 'v2.6', ('v8.38', '8.38', '838')),
    ('gda', 'v8.36', 'gda-v8.36.cquery', 'v2.5', ('v8.36', '8.36', '836')),
    ('gda', 'v8.34', 'gda-v8.34.cquery', 'v2.4', ('v8.34', '8.34', '834')),
    ('gda', 'v8.32', 'gda-v8.32.cquery', 'v2.4', ('v8.32', '8.32', '832')),
    ('gda', 'v8.30', 'gda-v8.30.cquery', 'v2.4', ('v8.30', '8.30', '830')),
    ('gda', 'v8.30-lnls', 'gda-v8.30-lnls.cquery', 'v2.4', ('v8.30-lnls', '8.30-lnls', '830-lnls')),
    ('gda', 'v8.28', 'gda-v8.28.cquery', 'v2.4', ('v8.28', '8.28', '828')),
    ('gda', 'v8.26', 'gda-v8.26.cquery', 'v2.3', ('v8.26', '8.26', '826')),
    ('gda', 'v8.24', 'gda-v8.24.cquery', 'v2.3', ('v8.24', '8.24', '824')),
    ('gda', 'v8.22', 'gda-v8.22.cquery', 'v2.2', ('v8.22', '8.22', '822')),
    ('gda', 'v8.20', 'gda-v8.20.cquery', 'v2.2', ('v8.20', '8.20', '820')),
    ('gda', 'v8.18', 'gda-v8.18.cquery', 'v1.0', ('v8.18', '8.18', '818')),
    ('ida', 'master', 'ida-master.cquery', 'v2.5', ('master', 'trunk')),
    ('ida', 'v2.20', 'ida-v2.20.cquery', 'v2.4', ('v2.20', '2.20', '220')),
    ('ida', 'v2.19', 'ida-v2.19.cquery', 'v2.3', ('v2.19', '2.19', '219')),
    ('ida', 'v2.18', 'ida-v2.18.cquery', 'v2.3', ('v2.18', '2.18', '218')),
    ('ida', 'v2.17', 'ida-v2.17.cquery', 'v2.2', ('v2.17', '2.17', '217')),
    ('dawn', 'master', 'dawn-master.cquery', 'v2.7', ('master', 'trunk')),
    ('dawn', '1.6', 'dawn-v1.6.cquery', 'v2.6', ('v1.6', '1.6')),
    ('dawn', '1.5', 'dawn-v1.5.cquery', 'v2.6', ('v1.5', '1.5')),
    ('dawn', '1.4.1', 'dawn-v1.4.1.cquery', 'v2.5', ('v1.4.1', '1.4.1')),
    ('dawn', '1.4', 'dawn-v1.4.cquery', 'v2.5', ('v1.4', '1.4')),
    ('dawn', 'gda-8.42', 'dawn-gda-8.42.cquery', 'v2.6', ('gda-8.42', 'gda842')),
    ('dawn', 'gda-8.40', 'dawn-gda-8.40.cquery', 'v2.6', ('gda-8.40', 'gda840')),
    ('dawn', 'gda-8.38', 'dawn-gda-8.38.cquery', 'v2.6', ('gda-8.38', 'gda838')),
    ('dawn', 'gda-8.36', 'dawn-gda-8.36.cquery', 'v2.5', ('gda-8.36', 'gda836')),
    ('dawn', 'gda-8.34', 'dawn-gda-8.34.cquery', 'v2.4', ('gda-8.34', 'gda834')),
    ('dawn', 'gda-8.32', 'dawn-gda-8.32.cquery', 'v2.4', ('gda-8.32', 'gda832')),
    ('dawn', 'gda-8.30', 'dawn-gda-8.30.cquery', 'v2.4', ('gda-8.30', 'gda830')),
    ('dawn', 'gda-8.28', 'dawn-gda-8.28.cquery', 'v2.4', ('gda-8.28', 'gda828')),
    ('dawn', 'v1.0', 'dawn-v1.0.cquery', 'v2.3', ('v1.0', '1.0')),
    ('none', 'master', 'master.cquery', 'v2.3', ('master', 'trunk')),
    ('training', 'master', 'training-trunk.cquery', 'v2.0', ('master', 'trunk')),
    ('training', 'v8.16', 'training-v8.16.cquery', 'v2.0', ('v8.16', '8.16', '816')),
    ('gda-training', 'v8.18', 'gda-training-v8.18.cquery', 'v1.0', ('v8.18', '8.18', '818')),
    )

CATEGORIES_AVAILABLE = []  # dedupe COMPONENT_CATEGORIES while preserving order
for c in COMPONENT_CATEGORIES:
    if c[0] not in CATEGORIES_AVAILABLE:
        CATEGORIES_AVAILABLE.append(c[0])
TEMPLATES_AVAILABLE = sorted(set(c[3] for c in COMPONENT_CATEGORIES))
DEFAULT_TEMPLATE_VERSION = TEMPLATES_AVAILABLE[-1]  # the most recent

PLATFORMS_AVAILABLE =  (
    # os/ws/arch, acceptable abbreviations
    ('linux,gtk,x86', ('linux,gtk,x86', 'linux32')),
    ('linux,gtk,x86_64', ('linux,gtk,x86_64', 'linux64')),
    ('win32,win32,x86', ('win32,win32,x86', 'win32', 'windows32',)),
    ('win32,win32,x86_64', ('win32,win32,x86_64', 'win64', 'windows64',)),
    ('macosx,cocoa,x86', ('macosx,cocoa,x86', 'macosx32', 'mac32',)),
    ('macosx,cocoa,x86_64', ('macosx,cocoa,x86_64', 'macosx64', 'mac64',)),
    )


class DawnException(Exception):
    """ Exception class to handle case when the setup does not support the requested operation. """
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return self.value

###############################################################################
#  Main class                                                                 #
###############################################################################

class DawnManager(object):

    def __init__(self):
        # Set up logger
        self.logger = logging.getLogger("Dawn")
        self.logger.setLevel(1)

        formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s", "%Y-%m-%d %H:%M:%S")
        # create console handler
        self.logging_console_handler = logging.StreamHandler()
        self.logging_console_handler.setFormatter(formatter)
        self.logger.addHandler(self.logging_console_handler)

        self.system = platform.system()
        self.isLinux = self.system == 'Linux'
        self.isWindows = self.system == 'Windows'
        self.java_version_reported = False
        self.executable_locations_reported = []

        self.valid_actions_with_help = (
            # 1st item in tuple is the action verb
            # 2nd item in tuple is the action special handler (either "ant" or None)
            # 3rd item in tuple is a tuple of help text lines
            ('setup', None,
                ('setup [ <template_workspace_version> ]',
                 'Set up a new workspace, with the target platform defined, but otherwise empty',
                 'Template can be one of "%s" (defaults to newest)' % '/'.join(TEMPLATES_AVAILABLE),
                 )),
            ('materialize', None,
                ('materialize <component> [<category> [<version>] | <cquery>]',
                 'Materialize a component and its dependencies into a new or existing workspace',
                 'Component can be abbreviated in many cases (eg just the beamline name is sufficient)',
                 'Category can be one of "%s"' % '/'.join(CATEGORIES_AVAILABLE),
                 'Version defaults to master',
                 'CQuery is only required if you need to override the computed value',
                 )),
            ('git', None, ('git <command>', 'Issue "git <command>" for all git clones',)),
            ('clean', None, ('clean', 'Clean the workspace',)),
            ('bmclean', None, ('bmclean <site>', 'Clean previous buckminster output',)),
            ('build', None, ('build', '[alias for buildthorough]',)),
            ('buildthorough', None, ('buildthorough', 'Build the workspace (do full build if first incremental build fails)',)),
            ('buildinc', None, ('buildinc', 'Build the workspace (incremental build)',)),
            ('target', None, ('target', 'List target definitions known in the workspace',)),
            ('target', None, ('target path/to/name.target', 'Set the target platform for the workspace',)),
            ('maketp', None, ('maketp', 'Create template tp/ in an existing workspace (you then need to import the project)',)),
            ('sites', None, ('sites', 'List the available site projects in the workspace',)),
            ('site.p2', None,
                ('site.p2 <site>',
                 'Build the workspace and an Eclipse p2 site',
                 'Site can be omitted if there is just one site project, and abbreviated in most other cases',
                )),
            ('site.p2.zip', None,
                ('site.p2.zip <site>',
                 'Build the workspace and an Eclipse p2 site, then zip the p2 site',
                 'Site can be omitted if there is just one site project, and abbreviated in most other cases',
                )),
            ('product', None,
                ('product <site> [ <platform> ... ]',
                 'Build the workspace and an Eclipse product',
                 'Site can be omitted if there is just one site project, and abbreviated in most other cases',
                 'Platform can be something like linux32/linux64/win32/all (defaults to current platform)',
                )),
            ('product.zip', None,
                ('product.zip <site> [ <platform> ... ]',
                 'Build the workspace and an Eclipse product, then zip the product',
                )),
            ('tests-clean', self._iterate_ant, ('tests-clean', 'Delete test output and results files from JUnit/JyUnit tests',)),
            ('junit-tests', self._iterate_ant, ('junit-tests', 'Run Java JUnit tests for all (or selected) projects',)),
            ('jyunit-tests', self._iterate_ant, ('jyunit-tests', 'Runs JyUnit tests for all (or selected) projects',)),
            ('all-tests', self._iterate_ant, ('all-tests', 'Runs both Java and JyUnit tests for all (or selected) projects',)),
            ('corba-make-jar', self._iterate_ant, ('corba-make-jar', '(Re)generate the corba .jar(s) in all or selected projects',)),
            ('corba-validate-jar', self._iterate_ant, ('corba-validate-jar', 'Check that the corba .jar(s) in all or selected plugins match the source',)),
            ('corba-clean', self._iterate_ant, ('corba-clean', 'Remove temporary files from workspace left over from corba-make-jar',)),
            ('dummy', self._iterate_ant, ()),
            )

        self.valid_actions = dict((action, handler) for (action, handler, help) in self.valid_actions_with_help)

        # if the current directory, or any or its parents, is a workspace, make that the default workspace
        # otherwise, if the directory the script is being run from is within a workspace, make that the default workspace
        self.workspace_loc = None
        candidate = os.getcwd()
        while candidate != os.path.dirname(candidate):  # if we are not at the filesystem root (this is a platform independent check)
            if not candidate.endswith('_git'):
                self.workspace_loc = (os.path.isdir( os.path.join( candidate, '.metadata')) and candidate)
            else:
                self.workspace_loc = (os.path.isdir( os.path.join( candidate[:-4], '.metadata')) and candidate[:-4])
            if self.workspace_loc:
                break
            candidate = os.path.dirname(candidate)

    def define_parser(self):
        """ Define all the command line options and how they are handled. """

        self.parser = optparse.OptionParser(usage="usage: %prog [options] action [arguments ...]", add_help_option=False,
            description="For more information, see the Infrastructure guide at http://www.opengda.org/documentation/")
        self.parser.disable_interspersed_args()
        self.parser.formatter.help_position = self.parser.formatter.max_help_position = 46  # improve look of help
        if not os.environ.has_key('COLUMNS'):  # typically this is not passed from the shell to the child process (Python)
            self.parser.formatter.width = 120  # so avoid the default of 80 and assume a wider terminal (improve look of help)

        group = optparse.OptionGroup(self.parser, "Workspace options")
        group.add_option('-w', '--workspace', dest='workspace', type='string', metavar='<dir>', default=self.workspace_loc,
                               help='Workspace location (default: %default)')
        group.add_option('--delete', dest='delete', action='store_true', default=False,
                               help='First completely delete current workspace and workspace_git')
        group.add_option('--unlink', dest='unlink', action='store_true', default=False,
                               help='First delete current workspace\'s .metadata')
        self.parser.add_option_group(group)

        group = optparse.OptionGroup(self.parser, "Materialize options")
        group.add_option('-l', '--location', dest='download_location', choices=('diamond', 'public'), metavar='<location>',
                         help='Download location ("diamond" or "public")')
        group.add_option('-k', '--keyring', dest='keyring', type='string', metavar='<path>',
                         help='Keyring file (for subversion authentication)')
        group.add_option('--materialize.properties.file', dest='materialize_properties_file', type='string', metavar='<path>',
                               default='materialize-properties.txt',
                               help='Properties file, relative to workspace if not absolute (default: %default)')
        group.add_option('--maxParallelMaterializations', dest='maxParallelMaterializations', type='int', metavar='<value>',
                         help='Override Buckminster default')
        group.add_option('--maxParallelResolutions', dest='maxParallelResolutions', type='int', metavar='<value>',
                         help='Override Buckminster default')
        self.parser.add_option_group(group)

        group = optparse.OptionGroup(self.parser, "Build/Product options")
        group.add_option('--suppress-compile-warnings', dest='suppress_compile_warnings', action='store_true', default=False,
                               help='Don\'t print compiler warnings')
        group.add_option('--buckminster.properties.file', dest='buckminster_properties_file', type='string', metavar='<path>',
                         help='Properties file, relative to site project if not absolute (default: filenames looked for in order: buckminster.properties, buckminster.beamline.properties)')
        group.add_option('--buckminster.root.prefix', dest='buckminster_root_prefix', type='string', metavar='<path>',
                         help='Prefix for buckminster.output.root and buckminster.temp.root properties')
        self.parser.add_option_group(group)

        group = optparse.OptionGroup(self.parser, "Test/Corba options")
        group.add_option('--include', dest='plugin_includes', type='string', metavar='<pattern>,<pattern>,...', default="",
                               help='Only process plugin names matching one or more of the glob patterns')
        group.add_option('--exclude', dest='plugin_excludes', type='string', metavar='<pattern>,<pattern>,...', default="",
                               help='Do not process plugin names matching any of the glob patterns')
        default_GDALargeTestFilesLocation = '/dls_sw/dasc/GDALargeTestFiles/'  # location at Diamond
        if not os.path.isdir(default_GDALargeTestFilesLocation):
            default_GDALargeTestFilesLocation=""
        group.add_option("--GDALargeTestFilesLocation", dest="GDALargeTestFilesLocation", type="string", metavar=" ", default=default_GDALargeTestFilesLocation,
                         help="Default: %default")
        self.parser.add_option_group(group)

        group = optparse.OptionGroup(self.parser, "General options")
        group.add_option('-D', dest='system_property', action='append', metavar='key=value',
                               help='Pass a system property to Buckminster or Ant')
        group.add_option('-J', dest='jvmargs', action='append', metavar='key=value',
                               help='Pass an additional JVM argument')
        group.add_option('-h', '--help', dest='help', action='store_true', default=False, help='Show help information and exit')
        group.add_option('-n', '--dry-run', dest='dry_run', action='store_true', default=False,
                               help='Log the actions to be done, but don\'t actually do them')
        group.add_option('--assume-build', dest='assume_build', action='store_true', default=False, help='Skip explicit build when running "site.p2" or "product" actions')
        group.add_option('-s', '--script-file', dest='script_file', type='string', metavar='<path>',
                               default='dawn-script.txt',
                               help='Script file, relative to workspace if not absolute (default: %default)')
        group.add_option('-q', '--quiet', dest='log_level', action='store_const', const='WARNING', help='Shortcut for --log-level=WARNING')
        group.add_option('--log-level', dest='log_level', type='choice', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], metavar='<level>',
                               default='INFO', help='Logging level (default: %default)')
        group.add_option('--keep-proxy', dest='keep_proxy', action='store_true', default=False, help='Never set the http_proxy[s] and no_proxy environment variables')
        self.parser.add_option_group(group)

        group = optparse.OptionGroup(self.parser, "Git/Svn options")
        group.add_option('-p', '--prefix', dest='repo_prefix', action='store_true', default=False, help='Prefix first line of git command output with the repo directory name.')
        self.parser.add_option_group(group)

    def setup_workspace(self):
        # create the workspace if it doesn't exist, initialise the workspace if it is not set up

        if os.path.isdir(self.workspace_loc):
            if ((os.path.exists( os.path.join(self.workspace_loc, '.metadata'))) and
             (os.listdir( os.path.join(self.workspace_loc, '.metadata')))):
                self.logger.info('Workspace already exists "%s"' % (self.workspace_loc,))
            else:
                self.logger.debug('Workspace directory already exists "%s", but is missing .metadata' % (self.workspace_loc,))
        else:
            self.logger.info('%sCreating workspace directory "%s"' % (self.log_prefix, self.workspace_loc,))
            if not self.options.dry_run:
                os.makedirs(self.workspace_loc)
        if self.workspace_git_loc and os.path.isdir(self.workspace_git_loc):
            self.logger.info('Using any existing .git repositories (which will not be updated) found in "%s"' % (self.workspace_git_loc,))

        if (not os.path.exists( os.path.join(self.workspace_loc, '.metadata'))) or (not os.listdir( os.path.join(self.workspace_loc, '.metadata'))):
            if (not os.path.exists( os.path.join( self.workspace_loc, 'tp'))) or (not os.listdir( os.path.join(self.workspace_loc, 'tp'))):
                # Case 1. Workspace does not have .metadata/, and does not have tp/.
                # Use the template workspace versions of .metadata/ and tp/.
                template_zip = os.path.join( self.workspace_loc, self.template_name )
                self.download_workspace_template( 'http://www.opengda.org/buckminster/templates/' + self.template_name, template_zip)
                self.unzip_workspace_template(template_zip, None, self.workspace_loc)
                self.logger.info('%sDeleting "%s"' % (self.log_prefix, template_zip,))
                if not self.options.dry_run:
                    os.remove(template_zip)
                return self.run_buckminster_in_subprocess(('clean',))  # for some reason this must be done
            else:
                # Case 2. Workspace does not have .metadata/, but does have tp/.
                # Use the template workspace version of .metadata/, and the existing tp/.
                template_zip = os.path.join( self.workspace_loc, self.template_name )
                self.download_workspace_template( 'http://www.opengda.org/buckminster/templates/' + self.template_name, template_zip)
                self.unzip_workspace_template(template_zip, '.metadata/', self.workspace_loc)
                self.logger.info('%sDeleting "%s"' % (self.log_prefix, template_zip,))
                if not self.options.dry_run:
                    os.remove(template_zip)
                return self.run_buckminster_in_subprocess(('clean',))  # for some reason this must be done

    def delete_directory(self, directory, description):
        if directory and os.path.isdir(directory):
            self.logger.info('%sDeleting %s "%s"' % (self.log_prefix, description, directory,))
            if not self.options.dry_run:
                # shutil.rmtree(directory)  # does not work under Windows of there are read-only files in the directory, such as.svn\all-wcprops
                if self.isLinux:
                    retcode = subprocess.call(('rm', '-rf', directory), shell=False)
                elif self.isWindows:
                    retcode = subprocess.call(('rmdir', '/s', '/q', directory), shell=True)
                else:
                    self.logger.error('Could not delete directory: platform "%s" not recognised' % (self.system,))

    def unlink_workspace(self):
        self.delete_directory(os.path.join(self.workspace_loc, '.metadata'), 'workspace metadata directory')

    def download_workspace_template(self, source, destination):
        self.logger.info('%sDownloading "%s" to "%s"' % (self.log_prefix, source, destination))
        if self.options.dry_run:
            return
        urllib.urlretrieve(source, destination)

    def unzip_workspace_template(self, template_zip, member, unzipdir):
        self.logger.info('%sUnzipping "%s%s" to "%s"' % (self.log_prefix, template_zip, '/' +
            member if member else '', unzipdir))  ### requires python 2.6+, Diamond RH5 requires "module load python"
        if self.options.dry_run:
            return
        template = zipfile.ZipFile(template_zip, 'r')
        self.logger.debug('Comment in zip file "%s"' % (template.comment,))
        if not member:
            template.extractall(unzipdir)
        else:
            template.extract(member, unzipdir)
        template.close()


    def set_available_sites(self):
        """ Sets self.available_sites, a dictionary of {site name: project path} entries,
            for all .site projects in the workspace or workspace_git directories
        """

        # we cache self.available_sites and never recompute
        if hasattr(self, 'available_sites'):
            return

        sites = {}
        for parent_dir in [os.path.join(self.workspace_loc, 'sites'), os.path.join(self.workspace_loc, 'features')]:
            # .site projects will be exactly one directory level below the sites/ or features/ directory
            if os.path.isdir(parent_dir):
                for site_dir in os.listdir(parent_dir):
                    if site_dir.endswith('.site') and os.path.exists( os.path.join(parent_dir, site_dir, 'feature.xml')):
                        sites[site_dir] = os.path.join(parent_dir, site_dir)
        if self.workspace_git_loc:
            # .site projects can be up to three directory levels below the git materialize directory
            for level1 in os.listdir(self.workspace_git_loc):
                level1_dir = os.path.join(self.workspace_git_loc, level1)
                for level2 in os.listdir(level1_dir):
                    level2_dir = os.path.join(level1_dir, level2)
                    if os.path.isdir(level2_dir):
                        if level2.endswith('.site') and os.path.exists( os.path.join(level2_dir, 'feature.xml')):
                            sites[level2] = level2_dir
                        else:
                            for level3 in os.listdir(level2_dir):
                                level3_dir = os.path.join(level2_dir, level3)
                                if os.path.isdir(level3_dir):
                                    if level3.endswith('.site') and os.path.exists( os.path.join(level3_dir, 'feature.xml')):
                                        sites[level3] = level3_dir
        self.available_sites = sites


    def set_all_matching_sites(self, site_name_part=None):
        """ Sets self.all_matching_sites, a sorted list of site names,
            for all .site projects that have site_name_part as a substring
        """

        # we cache self.all_matching_sites and only recompute if site_name_part changes
        if hasattr(self, 'all_matching_sites') and hasattr(self, 'all_matching_sites_name_part') and (self.all_matching_sites_name_part == site_name_part):
            return

        self.set_available_sites()
        if site_name_part:
            all_matching_sites = sorted(s for s in self.available_sites if site_name_part in s)
        else:
            all_matching_sites = sorted(self.available_sites)
        self.all_matching_sites_name_part = site_name_part
        self.all_matching_sites = all_matching_sites


    def set_site_name(self, site_name_part=None, must_exist=True):
        """ Sets self.site_name, a single site name that has site_name_part as a substring
            Raise an exception if not exactly one match
        """

        if hasattr(self, 'site_name') and hasattr(self, 'site_name_name_part') and (self.site_name_name_part == site_name_part):
            return

        self.set_all_matching_sites(site_name_part)
        if len(self.all_matching_sites) == 1:
            self.site_name_name_part = site_name_part
            self.site_name = self.all_matching_sites[0]
            return
        if self.all_matching_sites:
            if site_name_part:
                raise DawnException('ERROR: More than 1 .site project matches substring "%s" %s, try a longer substring' % (site_name_part, tuple(self.all_matching_sites)))
            else:
                raise DawnException('ERROR: More than 1 .site project available, you must specify which is required, from: %s' % (tuple(self.all_matching_sites),))
        elif must_exist:
            if site_name_part:
                raise DawnException('ERROR: No .site project matching substring "%s" found in %s' % (site_name_part, self.all_matching_sites))
            else:
                raise DawnException('ERROR: No .site project in workspace')


    def validate_plugin_patterns(self):
        for glob_patterns in (self.options.plugin_includes, self.options.plugin_excludes):
            if glob_patterns:
                for pattern in glob_patterns.split(","):
                    if not pattern:
                        raise DawnException("ERROR: --include or --exclude contains an empty plugin pattern")
                    if pattern.startswith("-") or ("=" in pattern):
                        # catch a possible error in command line construction
                        raise DawnException("ERROR: --include or --exclude contains an invalid plugin pattern \"%s\"" % (p,))


    def set_all_plugins_with_releng_ant(self):
        """ Finds all the plugins in the self.workspace_git_loc directory, provided they contain a releng.ant file plus compiled code.
            Result is a dictionary of {plugin-name: relative/path/to/plugin} (the path is relative to self.workspace_git_loc)
        """

        plugin_names_paths = {}
        for root, dirs, files in os.walk(self.workspace_git_loc):
            for d in dirs[:]:
                if d.startswith('.') or d.endswith(('.feature', '.site')):
                    dirs.remove(d)
            if 'releng.ant' in files:
                dirs = []  # plugins are never nested inside plugins, so no need to look beneath this directory
                bin_dir_path = os.path.join(root, 'classes' if os.path.basename(root) == 'uk.ac.gda.core' else 'bin')
                if os.path.isdir(bin_dir_path):
                    # only include this plugin if it contains compiled code (in case the filesystem contains a repo, but the workspace did not import all the projects)
                    for proot, pdirs, pfiles in os.walk(bin_dir_path):
                        for d in pdirs[:]:
                            if d.startswith('.'):
                                pdirs.remove(d)
                        if [f for f in pfiles if not f.startswith('.')]:  # if any non-hidden file in the bin_dir_path directory
                            # return plugin path relative to the parent directory, and plugin name (these will be the same for the subversion plugins)
                            assert os.path.basename(root) not in plugin_names_paths
                            plugin_names_paths[os.path.basename(root)] = os.path.relpath(root, self.workspace_git_loc)
                            break
        self.all_plugins_with_releng_ant = plugin_names_paths


    def get_matching_plugins_with_releng_ant(self, glob_patterns):
        """ Finds all the plugin names that match the specified glob patterns (either --include or --exclude).
        """
        matching_paths_names = []

        for p in glob_patterns.split(","):
            matching_paths_names.extend(fnmatch.filter(self.all_plugins_with_releng_ant.keys(), p))
        return sorted( set(matching_paths_names) )


    def get_selected_plugins_with_releng_ant(self):
        """ Finds all the plugin names that match the specified glob patterns (combination of --include and --exclude).
            If neither --include nor --exclude specified, return the empty string
        """

        if self.options.plugin_includes or self.options.plugin_excludes:
            self.set_all_plugins_with_releng_ant()

            if self.options.plugin_includes:
                included_plugins = self.get_matching_plugins_with_releng_ant(self.options.plugin_includes)
            else:
                included_plugins = self.all_plugins_with_releng_ant

            if self.options.plugin_excludes:
                excluded_plugins = self.get_matching_plugins_with_releng_ant(self.options.plugin_excludes)
            else:
                excluded_plugins = []

            selected_plugins = sorted(set(included_plugins) - set(excluded_plugins))

            if not selected_plugins:
                raise DawnException("ERROR: no compiled plugins matching --include=%s --exclude=%s found" % (self.options.plugin_includes, self.options.plugin_excludes))
            return "-Dplugin_list=\"%s\"" % '|'.join([self.all_plugins_with_releng_ant[pname] for pname in selected_plugins])

        return ""


    def set_buckminster_properties_path(self, site_name=None):
        """ Sets self.buckminster_properties_path, the absolute path to the buckminster properties file in the specified site
        """

        if self.options.buckminster_properties_file:
            buckminster_properties_path = os.path.expanduser(self.options.buckminster_properties_file)
            if not os.path.isabs(buckminster_properties_path):
                buckminster_properties_path = os.path.abspath(os.path.join(self.available_sites[site_name], self.options.buckminster_properties_file))
            if not os.path.isfile(buckminster_properties_path):
                raise DawnException('ERROR: Properties file "%s" does not exist' % (buckminster_properties_path,))
            self.buckminster_properties_path = buckminster_properties_path
        else:
            buckminster_properties_paths = [os.path.abspath(os.path.join(self.available_sites[site_name], buckminster_properties_file))
                                            for buckminster_properties_file in ('buckminster.properties', 'buckminster.beamline.properties')]
            for buckminster_properties_path in buckminster_properties_paths:
                if os.path.isfile(buckminster_properties_path):
                        self.buckminster_properties_path = buckminster_properties_path
                        break
            else:
                raise DawnException('ERROR: Neither properties file "%s" exists' % (buckminster_properties_paths,))

###############################################################################
#  Actions                                                                    #
###############################################################################

    def action_setup(self):
        """ Processes command: setup [ <template_workspace_version> ]
        """

        if len(self.arguments) > 1:
            raise DawnException('ERROR: setup command has too many arguments')
        if self.arguments:
            template = self.arguments[0]
            if template not in TEMPLATES_AVAILABLE:
                raise DawnException('ERROR: template "%s" not recognised (must be one of "%s")' % (template, '/'.join(TEMPLATES_AVAILABLE)))
        else:
            template = DEFAULT_TEMPLATE_VERSION
        self.template_name = 'template_workspace_%s.zip' % (template,)
        self.setup_workspace()
        return


    def action_materialize(self):
        """ Processes command: materialize <component> [<category> [<version>] | <cquery>]
        """

        if len(self.arguments) < 1:
            raise DawnException('ERROR: materialize command has too few arguments')
        if len(self.arguments) > 3:
            raise DawnException('ERROR: materialize command has too many arguments')

        category_to_use = normalized_version_name = cquery_to_use = template_to_use = None

        # interpret any (category / category version / cquery) arguments
        if len(self.arguments) > 1:
            category_or_cquery = self.arguments[1]
            if category_or_cquery.endswith('.cquery'):
                cquery_to_use = category_or_cquery
                if len(self.arguments) > 2:
                    raise DawnException('ERROR: No other options can follow the CQuery')
                for c,v,q,t,s in [cc for cc in COMPONENT_CATEGORIES if cc[2] == cquery_to_use]:
                    template_to_use = t
                    break
                else:
                    template_to_use = DEFAULT_TEMPLATE_VERSION
            elif category_or_cquery in CATEGORIES_AVAILABLE:
                category_to_use = category_or_cquery
                if len(self.arguments) > 2:
                    version = self.arguments[2]
                    for c,v,q,t,s in [cc for cc in COMPONENT_CATEGORIES if cc[0] == category_to_use]:
                        if version in s:
                            normalized_version_name = v
                            break
                    else:
                        raise DawnException('ERROR: category "%s" is not consistent with version "%s"' % (category_to_use, version))
            else:
                raise DawnException('ERROR: "%s" is neither a category nor a CQuery' % (category_or_cquery,))
            # at this point, if more than a single argument (component), we have determined either:
            # category_to_use
            # category_to_use, normalized_version_name
            # cquery_to_use
            # cquery_to_use, template_to_use

        # translate an abbreviated component name to the real component name
        component_to_use = self.arguments[0]
        for abbrev, cat, actual in COMPONENT_ABBREVIATIONS:
            if component_to_use == abbrev:
                component_to_use = actual
                if category_to_use:
                    if category_to_use != cat:
                        raise DawnException('ERROR: component "%s" is not consistent with category "%s"' % (component_to_use, category_to_use,))
                else:
                    category_to_use = cat
        else:
            pass  # assume component is exactly specified and does not need to be interpreted
        if not (category_to_use or cquery_to_use):
            raise DawnException('ERROR: the category for component "%s" is missing (can be one of %s)' % (component_to_use, '/'.join(CATEGORIES_AVAILABLE)))


        if not cquery_to_use:
            # determine the template workspace to use if one is required
            assert category_to_use
            if not normalized_version_name:
                normalized_version_name = 'master'
            template_to_use_list = [cc[3] for cc in COMPONENT_CATEGORIES if cc[0] == category_to_use and cc[1] == normalized_version_name]
            assert len(template_to_use_list) == 1
            template_to_use = template_to_use_list[0]
            # determine the CQuery to use (if not explicitly requested)
            cquery_to_use_list = [cc[2] for cc in COMPONENT_CATEGORIES if cc[0] == category_to_use and cc[1] == normalized_version_name]
            assert len(cquery_to_use_list) == 1
            cquery_to_use = cquery_to_use_list[0]
        assert template_to_use and cquery_to_use

        # create the workspace if required
        self.template_name = 'template_workspace_%s.zip' % (template_to_use,)
        exit_code = self.setup_workspace()
        if exit_code:
            self.logger.info('Abandoning materialize: workspace setup failed')
            return exit_code

        self.logger.info('Writing buckminster materialize properties to "%s"' % (self.materialize_properties_path,))
        with open(self.materialize_properties_path, 'w') as properties_file:
            properties_file.write('component=%s\n' % (component_to_use,))
            if self.options.download_location:
                properties_file.write('download.location.common=%s\n' % (self.options.download_location,))

        self.logger.info('Writing buckminster commands to "%s"' % (self.script_file_path,))
        properties_text = '-P%s ' % (self.materialize_properties_path.replace('\\','/'),)  # convert \ to / in path on Windows (avoiding \ as escape character)
        for keyval in self.options.system_property:
            properties_text += '-D%s ' % (keyval,)
        with open(self.script_file_path, 'w') as script_file:
            # set preferences
            if self.options.maxParallelMaterializations:
                script_file.write('setpref maxParallelMaterializations=%s\n' % (self.options.maxParallelMaterializations,))
            if self.options.maxParallelResolutions:
                script_file.write('setpref maxParallelResolutions=%s\n' % (self.options.maxParallelResolutions,))
            script_file.write('import ' + properties_text)
            script_file.write('http://www.opengda.org/buckminster/base/%s\n' % (cquery_to_use,))

        if self.isWindows:
            script_file_path_to_pass = '"%s"' % (self.script_file_path,)
        else:
            script_file_path_to_pass = self.script_file_path
        return self.run_buckminster_in_subprocess(('--scriptfile', script_file_path_to_pass))

    def action_git(self):
        """ Processes command: git <command>
        """

        if len(self.arguments) < 1:
            raise DawnException('ERROR: git command has too few arguments')

        if not self.workspace_git_loc:
            self.logger.info('%sSkipped: %s' % (self.log_prefix, self.workspace_loc + '_git does not exist'))
            return

        git_directories = []
        for root, dirs, files in os.walk(self.workspace_git_loc):
            if os.path.basename(root) == '.git':
                raise DawnException('ERROR: action_git attempted to recurse into a .git directory: %s' % (root,))
            if os.path.basename(root).startswith('.'):
                # don't recurse into hidden directories
                self.logger.debug('%sSkipping: %s' % (self.log_prefix, root))
                dirs[:] = []
                continue
            if '.git' in dirs:
                # if this directory is the top level of a git checkout, remember it
                git_directories.append(os.path.join(self.workspace_git_loc, root))
                dirs[:] = []  # do not recurse into this directory
            else:
                self.logger.debug('%sChecking: %s' % (self.log_prefix, root))
        assert len(git_directories) == len(set(git_directories))  # should be no duplicates

        if len(git_directories) == 0:
            return

        prefix= "%%%is: " % max([len(os.path.basename(x)) for x in git_directories]) if self.options.repo_prefix else ""

        max_retcode = 0
        for git_dir in sorted(git_directories):
            git_command = 'git ' + ' '.join(self.arguments)

            if git_command.strip() == 'git pull':
                has_remote = False
                config_path = os.path.join(git_dir, '.git', 'config')
                if os.path.isfile(config_path):
                    with open(config_path, 'r' ) as config:
                        for line in config:
                            if '[remote ' in line:
                                has_remote = True
                                break
                if not has_remote:
                    self.logger.info('%sSkipped: %s in %s (NO REMOTE DEFINED)' % (self.log_prefix, git_command, git_dir))
                    continue

            retcode = self.action_one_git_repo(git_command, git_dir, prefix)
            max_retcode = max(max_retcode, retcode)

        return max_retcode

    def action_one_git_repo(self, command, directory, prefix):
        self.logger.info('%sRunning: %s in %s' % (self.log_prefix, command, directory))

        if not self.options.dry_run:
            sys.stdout.flush()
            sys.stderr.flush()
            try:
                # set environment variables to pass to git command extensions 
                os.environ['DAWN_PY_WORKSPACE_GIT_LOC'] = self.workspace_git_loc
                os.environ['DAWN_PY_COMMAND'] = str(command)
                os.environ['DAWN_PY_DIRECTORY'] = str(directory)
                process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, cwd=directory)
                out,err = process.communicate()
                out,err = out.rstrip(),err.rstrip()
                retcode = process.returncode
            except OSError:
                raise DawnException('ERROR: "%s" failed in %s: %s' % (command, directory, sys.exc_value,))

            if self.options.repo_prefix:
                if len(out)!=0 or len(err)!=0:
                    print prefix % os.path.basename(directory).strip(),
                    if '\n' in out or '\r' in out: # if out is multiline
                        print "..."                # start it on a new line
                    elif '\n' in err or '\r' in err: # if err is multiline
                        print "..."                # start it on a new line
                if len(err)!=0:
                    print >> sys.stderr, err
                if len(out)!=0:
                    print out
            else:
                print >> sys.stderr, err
                print out
            sys.stderr.flush()
            sys.stdout.flush()
            if retcode:
                self.logger.error('Return Code: %s running: %s in %s'% (retcode, command, directory))
            else:
                self.logger.debug('Return Code: %s' % (retcode,))
            return retcode

    def action_clean(self):
        """ Processes command: clean
        """
        return self.run_buckminster_in_subprocess(('clean',))


    def action_bmclean(self):
        """ Processes command: bmclean
        """

        if len(self.arguments) > 1:
            raise DawnException('ERROR: bmclean command has too many arguments')

        self.set_site_name(self.arguments and self.arguments[0])
        self.set_buckminster_properties_path(self.site_name)
        self.logger.info('buckminster output for site "%s" will be cleaned' % (self.site_name,))

        self.logger.info('Writing buckminster commands to "%s"' % (self.script_file_path,))
        properties_text = '-P%s ' % (self.buckminster_properties_path,)
        for keyval in self.options.system_property:
            properties_text += '-D%s ' % (keyval,)
        if self.options.buckminster_root_prefix:
            properties_text += '-Dbuckminster.root.prefix=%s ' % (os.path.abspath(self.options.buckminster_root_prefix),)
        with open(self.script_file_path, 'w') as script_file:
            script_file.write('perform ' + properties_text)
            script_file.write('-Dtarget.os=* -Dtarget.ws=* -Dtarget.arch=* ')
            script_file.write('%(site_name)s#buckminster.clean\n' % {'site_name': self.site_name})

        if self.isWindows:
            script_file_path_to_pass = '"%s"' % (self.script_file_path,)
        else:
            script_file_path_to_pass = self.script_file_path
        return self.run_buckminster_in_subprocess(('--scriptfile', script_file_path_to_pass))


    def action_buildthorough(self):
        return self._action_build(thorough=True)
    def action_buildinc(self):
        return self._action_build(thorough=False)
    def action_build(self):
        return self._action_build(thorough=True)

    def _action_build(self, thorough):
        """ Processes command: build
        """

        self.logger.info('Writing buckminster commands to "%s"' % (self.script_file_path,))
        with open(self.script_file_path, 'w') as script_file:
            if thorough:
                script_file.write('build --thorough\n')
            else:
                script_file.write('build\n')

        if self.isWindows:
            script_file_path_to_pass = '"%s"' % (self.script_file_path,)
        else:
            script_file_path_to_pass = self.script_file_path
        return self.run_buckminster_in_subprocess(('--scriptfile', script_file_path_to_pass))

    def action_target(self):
        """ Processes command: target [ path/to/name.target ]
        """

        if not self.arguments:
            return self.run_buckminster_in_subprocess(('listtargetdefinitions',))

        if len(self.arguments) > 1:
            raise DawnException('ERROR: target command has too many arguments')

        target = self.arguments[0]
        if not target.endswith( '.target' ):
            raise DawnException('ERROR: target "%s" is not a valid target name (it must end with .target)' % (target,))

        if os.path.isabs(target):
            path = os.path.realpath(os.path.abspath(target))
            if not path.startswith( self.workspace_loc + os.sep ):
                raise DawnException('ERROR: target "%s" is not within the workspace ("%s")' % (path, self.workspace_loc))
        else:
            path = os.path.realpath(os.path.abspath(os.path.join(self.workspace_loc, target)))
        if not os.path.isfile(path):
            raise DawnException('ERROR: target file "%s" ("%s") does not exist' % (target, path))

        return self.run_buckminster_in_subprocess(('importtargetdefinition', '--active', path[len(self.workspace_loc)+1:]))  # +1 for os.sep


    def action_sites(self):
        sites = self.set_available_sites()
        self.logger.info('Available sites in %s%s: %s' % (self.workspace_loc, ('', '[_git]')[bool(self.workspace_git_loc)], sorted(self.available_sites) or '<none>'))


    def action_site_p2(self):
        return self._action_site_p2_or_action_site_p2_zip(action_zip=False)
    def action_site_p2_zip(self):
        return self._action_site_p2_or_action_site_p2_zip(action_zip=True)

    def _action_site_p2_or_action_site_p2_zip(self, action_zip):
        """ Processes command: site.p2 [ <site> ]
                           or: site.p2.zip [ <site> ]
        """

        if len(self.arguments) > 1:
            raise DawnException('ERROR: site.p2%s command has too many arguments' % ('','.zip')[action_zip])

        self.set_site_name(self.arguments and self.arguments[0])
        self.set_buckminster_properties_path(self.site_name)
        self.logger.info('p2 site "%s" will be built' % (self.site_name,))

        self.logger.info('Writing buckminster commands to "%s"' % (self.script_file_path,))
        properties_text = '-P%s ' % (self.buckminster_properties_path,)
        for keyval in self.options.system_property:
            properties_text += '-D%s ' % (keyval,)
        if self.options.buckminster_root_prefix:
            properties_text += '-Dbuckminster.root.prefix=%s ' % (os.path.abspath(self.options.buckminster_root_prefix),)
        with open(self.script_file_path, 'w') as script_file:
            if not self.options.assume_build:
                script_file.write('build --thorough\n')
            script_file.write('perform ' + properties_text)
            script_file.write('-Dtarget.os=* -Dtarget.ws=* -Dtarget.arch=* %(site_name)s#site.p2%(zip_action)s\n' %
                              {'site_name': self.site_name, 'zip_action': ('','.zip')[action_zip]})

        if self.isWindows:
            script_file_path_to_pass = '"%s"' % (self.script_file_path,)
        else:
            script_file_path_to_pass = self.script_file_path
        return self.run_buckminster_in_subprocess(('--scriptfile', script_file_path_to_pass))


    def action_product(self):
        return self._product_or_product_zip(action_zip=False)
    def action_product_zip(self):
        return self._product_or_product_zip(action_zip=True)

    def _product_or_product_zip(self, action_zip):
        """ Processes command: product [ <site> ] [ <platform> ... ]
                           or: product.zip [ <site> ] [ <platform> ... ]
        """

        self.set_available_sites()
        platforms = set()

        for (index, arg) in enumerate(self.arguments):
            # interpret any site / platform arguments, recognising that all arguments are optional
            if index == 0:
                self.set_site_name(arg, must_exist=False)
            if (index != 0) or (not hasattr(self, 'site_name')) or (not self.site_name):
                if arg == 'all':
                    for (p,a) in PLATFORMS_AVAILABLE:
                        platforms.add(p)
                else:
                    for (p, a) in PLATFORMS_AVAILABLE:
                        if arg in a:
                            platforms.add(p)
                            break
                    else:
                        raise DawnException('ERROR: "%s" was not recognised as either a site (in %s<_git>), or as a platform name' % (arg, self.workspace_loc))

        if not hasattr(self, 'site_name') or not self.site_name:
            self.set_site_name(None)
        if platforms:
            platforms = sorted(platforms)
        else:
            platforms = [{'Linuxi686': 'linux,gtk,x86', 'Linuxx86_64': 'linux,gtk,x86_64', 'Windowsx86': 'win32,win32,x86', 'Windowsx86_64': 'win32,win32,x86_64'}.get('%s%s' % (self.system, platform.machine()))]
        self.logger.info('Product "%s" will be built for %d platform%s: %s' % (self.site_name, len(platforms), ('','s')[bool(len(platforms)>1)], platforms))

        # determine whether cspex for the .site project specifies (newest to oldest):
        # (A) a separate action for each platform (create.product-<os>.<ws>.<arch>), and a separate zip action for each platform
        # (B) a separate action for each platform (create.product-<os>.<ws>.<arch>), but no separate zip action for each platform
        # (C) a single action for all platforms (create.product)

        cspex_file_path = os.path.abspath(os.path.join(self.available_sites[self.site_name], 'buckminster.cspex'))
        per_platform_actions_available = False
        zip_actions_available = False
        with open(cspex_file_path, 'r') as cspex_file:
            for line in cspex_file:
                if 'create.product-linux.gtk.x86' in line:
                    per_platform_actions_available = True
                if 'create.product.zip-linux.gtk.x86' in line:
                    zip_actions_available = True
                if per_platform_actions_available and zip_actions_available:
                    break

        if action_zip and not zip_actions_available:
            raise DawnException('ERROR: product.zip is not available for "%s"' % (self.site_name,))

        self.set_buckminster_properties_path(self.site_name)
        self.logger.info('Writing buckminster commands to "%s"' % (self.script_file_path,))
        properties_text = '-P%s ' % (self.buckminster_properties_path,)
        for keyval in self.options.system_property:
            properties_text += '-D%s ' % (keyval,)
        if self.options.buckminster_root_prefix:
            properties_text += '-Dbuckminster.root.prefix=%s ' % (os.path.abspath(self.options.buckminster_root_prefix),)
        with open(self.script_file_path, 'w') as script_file:
            if not self.options.assume_build:
                script_file.write('build --thorough\n')
            script_file.write('perform ' + properties_text)
            script_file.write('-Dtarget.os=* -Dtarget.ws=* -Dtarget.arch=* ')
            if per_platform_actions_available:
                for p in platforms:
                    perform_options = {'action': 'create.product.zip' if action_zip else 'create.product', 'site_name': self.site_name,
                                       'os': p.split(',')[0], 'ws': p.split(',')[1], 'arch': p.split(',')[2]}
                    script_file.write(' %(site_name)s#%(action)s-%(os)s.%(ws)s.%(arch)s' % perform_options)
                script_file.write('\n')
            else:
                script_file.write('%(site_name)s#site.p2\n' % {'site_name': self.site_name})
                for p in platforms:
                    perform_options = {'site_name': self.site_name, 'os': p.split(',')[0], 'ws': p.split(',')[1], 'arch': p.split(',')[2]}
                    script_file.write('perform ' + properties_text)
                    script_file.write('-Dtarget.os=%(os)s -Dtarget.ws=%(ws)s -Dtarget.arch=%(arch)s %(site_name)s#create.product\n' % perform_options)

        if self.isWindows:
            script_file_path_to_pass = '"%s"' % (self.script_file_path,)
        else:
            script_file_path_to_pass = self.script_file_path
        return self.run_buckminster_in_subprocess(('--scriptfile', script_file_path_to_pass))


    def action_maketp(self):
        """ Processes command: maketp
            Creates a tp/ directory and project. User should them import it into the workspace, and set it as the target platform.
            Since the template workspace contains tp/, this is only needed for non-standard setups.
        """

        project_file_text = r'''<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
        <name>tp</name>
        <comment></comment>
        <projects>
        </projects>
        <buildSpec>
        </buildSpec>
        <natures>
        </natures>
</projectDescription>
'''
        pydevproject_file_text = r'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<?eclipse-pydev version="1.0"?>

<pydev_project>
<pydev_property name="org.python.pydev.PYTHON_PROJECT_INTERPRETER">Default</pydev_property>
<pydev_property name="org.python.pydev.PYTHON_PROJECT_VERSION">jython 2.5</pydev_property>
<pydev_pathproperty name="org.python.pydev.PROJECT_SOURCE_PATH">
<path>/tp/plugins/org.apache.commons.math_2.2.0.jar</path>
<path>/tp/plugins/uk.ac.diamond.jama_1.0.1.jar</path>
<path>/tp/plugins/uk.ac.diamond.org.apache.xmlrpc.client_3.1.3.jar</path>
<path>/tp/plugins/uk.ac.diamond.org.apache.xmlrpc.common_3.1.3.jar</path>
<path>/tp/plugins/uk.ac.diamond.org.apache.xmlrpc.server_3.1.3.jar</path>
</pydev_pathproperty>
</pydev_project>
'''
        target_file_text = r'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<?pde version="3.6"?>
<target name="Dynamic Target">
<locations>
<location path="${workspace_loc}/tp" type="Directory"/>
</locations>
</target>
'''

        project_dir = os.path.join(self.workspace_loc, 'tp')
        if not os.path.isdir(project_dir):
            self.logger.info('%sCreating project directory %s' % (self.log_prefix, project_dir,))
            if not self.options.dry_run:
                os.mkdir(project_dir)

        project = os.path.join(project_dir, '.project')
        if not os.path.isfile(project):
            self.logger.info('%sCreating project file %s' % (self.log_prefix, project,))
            if not self.options.dry_run:
                with open(project, 'w') as project_file:
                    project_file.write(project_file_text)

        project = os.path.join(project_dir, '.pydevproject')
        if not os.path.isfile(project):
            self.logger.info('%sCreating PyDev project file %s' % (self.log_prefix, project,))
            if not self.options.dry_run:
                with open(project, 'w') as pydevproject_file:
                    pydevproject_file.write(pydevproject_file_text)

        target = os.path.join(project_dir, 'dynamic.target')
        if not os.path.isfile(target):
            self.logger.info('%sCreating target definition file %s' % (self.log_prefix, target,))
            if not self.options.dry_run:
                with open(target, 'w') as target_file:
                    target_file.write(target_file_text)

        self.logger.info('%stp/ set up - now import the project into your workspace, set the target platform, and restart Eclipse' % (self.log_prefix,))

    def _iterate_ant(self, target):
        """ Processes using an ant target
        """

        selected_plugins = self.get_selected_plugins_with_releng_ant()  # might be an empty string to indicate all
        self.run_ant_in_subprocess((selected_plugins, target))


###############################################################################
#  Run Buckminster                                                            #
###############################################################################

    def report_executable_location(self, executable_name):
        """ Logs the path to an executable (an actual version number is not available)
        """

        if (executable_name in self.executable_locations_reported) or (not self.isLinux):
            return
        loc = None
        try:
            whichrun = subprocess.Popen(('which', '--all', executable_name), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            (stdout, stderr) = whichrun.communicate(None)
            if not whichrun.returncode:
                loc = stdout.strip()
        except:
            pass
        if loc:
            self.logger.info('%s%s install that will be used: %s' % (self.log_prefix, executable_name, loc))
        else:
            self.logger.warn('%s%s install to be used could not be determined' % (self.log_prefix, executable_name))
        self.executable_locations_reported.append(executable_name)

    def report_java_version(self):
        """ Logs the Java version number, something like 1.7.0_17
        """

        if self.java_version_reported:
            return
        version = ''
        try:
            javarun = subprocess.Popen(('java', '-version'), stderr=subprocess.PIPE)  #  java -version writes to stderr
            (stdout, stderr) = javarun.communicate(None)
            if not javarun.returncode:
                if stderr.startswith('java version "'):
                    version = stderr[len('java version "'):].partition('"')[0]
        except:
            pass
        if version:
            self.logger.info('%sJava version that will be used: %s' % (self.log_prefix, version))
        else:
            self.logger.warn('%sJava version to use could not be determined' % (self.log_prefix,))
        self.java_version_reported = True

    def run_buckminster_in_subprocess(self, buckminster_args):
        """ Generates and runs the buckminster command
        """

        self.report_executable_location('buckminster')
        self.report_java_version()

        buckminster_command = ['buckminster']

        if self.options.keyring:
            buckminster_command.extend(('-keyring', '"%s"' % (self.options.keyring,)))  # quote in case of embedded blanks or special characters
        buckminster_command.extend(('-application', 'org.eclipse.buckminster.cmdline.headless'))
        buckminster_command.extend(('--loglevel', self.options.log_level.upper()))
        buckminster_command.extend(('-data', self.workspace_loc))  # do not quote the workspace name (it should not contain blanks)
        buckminster_command.extend(buckminster_args)
        # if debugging memory allocation, add this parameter: '-XX:+PrintFlagsFinal'
        if not self.isWindows:  # these extra options need to be removed on my Windows XP 32-bit / Java 1.7.0_25 machine
            buckminster_command.extend(('-vmargs', '-Xms768m', '-Xmx1536m', '-XX:MaxPermSize=128m', '-XX:+UseG1GC', '-XX:MaxGCPauseMillis=1000'))
        for keyval in self.options.jvmargs:
            buckminster_command.extend(('-D%s ' % (keyval,),))

        buckminster_command = ' '.join(buckminster_command)
        self.logger.info('%sRunning: %s' % (self.log_prefix, buckminster_command))
        try:
            scriptfile_index = buckminster_args.index('--scriptfile')
        except ValueError:
            pass  # no script file
        else:
            script_file_path_to_pass = buckminster_args[scriptfile_index+1]
            script_file_path_to_pass = script_file_path_to_pass.strip()  # remove leading whitespace
            if self.isWindows:
                assert script_file_path_to_pass.startswith('"')
                trailing_quote_index = script_file_path_to_pass.find('"', 2)
                assert trailing_quote_index != -1
                script_file_path_to_pass = script_file_path_to_pass[1:trailing_quote_index]  # remove surrounding quotes used on Windows
            with open(script_file_path_to_pass) as script_file:
                for line in script_file.readlines():
                    self.logger.debug('%s(script file): %s' % (self.log_prefix, line))

        if not self.options.dry_run:
            sys.stdout.flush()
            sys.stderr.flush()
            try:
                process = subprocess.Popen(buckminster_command, bufsize=1, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True)
                for line in iter(process.stdout.readline, b''):
                    if not (self.options.suppress_compile_warnings and line.startswith('Warning: file ')):
                        print line,  # trailing comma so we don't add an extra newline
                process.communicate() # close p.stdout, wait for the subprocess to exit                
                retcode = process.returncode
            except OSError:
                raise DawnException('ERROR: Buckminster failed: %s' % (sys.exc_value,))
            sys.stdout.flush()
            sys.stderr.flush()
            if retcode:
                self.logger.error('Return Code: %s' % (retcode,))
            else:
                self.logger.debug('Return Code: %s' % (retcode,))
            return retcode

    def run_ant_in_subprocess(self, ant_args):
        """ Generates and runs the ant command
        """

        self.report_executable_location('ant')
        self.report_java_version()

        ant_command = ['ant']
        ant_command.extend(("-logger", "org.apache.tools.ant.NoBannerLogger"))
        ant_command.extend(('-buildfile', os.path.join(self.workspace_git_loc, 'diamond-releng.git/diamond.releng.tools/ant-headless/ant-driver.ant')))

        # pass through GDALargeTestFilesLocation
        loc = self.options.GDALargeTestFilesLocation and self.options.GDALargeTestFilesLocation.strip()
        if loc:
            loc = os.path.expanduser(loc)
            if os.path.isdir(loc):
                if self.options.GDALargeTestFilesLocation.strip().endswith(os.sep):
                    ant_command.extend(("-DGDALargeTestFilesLocation=%s" % (loc,),))
                else:
                    ant_command.extend(("-DGDALargeTestFilesLocation=%s%s" % (loc, os.sep),))
            else:
                raise DawnException('ERROR: --GDALargeTestFilesLocation=%s does not exist. If any tests require this, they will fail.\n' % (loc,))
        for keyval in self.options.system_property:
            ant_command.extend(("-D%s " % (keyval,),))

        ant_command.extend(ant_args)

        ant_command = ' '.join(ant_command)
        self.logger.info('%sRunning: %s' % (self.log_prefix, ant_command))

        if not self.options.dry_run:
            sys.stdout.flush()
            sys.stderr.flush()
            try:
                process = subprocess.Popen(ant_command, bufsize=1, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True)
                for line in iter(process.stdout.readline, b''):
                    print line,  # trailing comma so we don't add an extra newline
                process.communicate() # close p.stdout, wait for the subprocess to exit                
                retcode = process.returncode
            except OSError:
                raise DawnException('ERROR: Ant failed: %s' % (sys.exc_value,))
            sys.stdout.flush()
            sys.stderr.flush()
            if retcode:
                self.logger.error('Return Code: %s' % (retcode,))
            else:
                self.logger.debug('Return Code: %s' % (retcode,))
            return retcode


###############################################################################
#  Main driver                                                                #
###############################################################################

    def main(self, call_args):
        """ Process any command line arguments and run program.
            call_args[0] == the directory the script is running from.
            call_args[1:] == build options and parameters. """

        if (sys.version < "2.6") or (sys.version >= "3"):
            raise DawnException("ERROR: This script must be run using Python 2.6 or higher.")
        try:
            if not len(call_args):
                raise TypeError
        except TypeError:
            raise DawnException("ERROR: DawnManager.main() called with incorrect argument.")

        start_time = datetime.datetime.now()

        # process command line arguments (prompt if necessary):
        self.define_parser()
        (self.options, positional_arguments) = self.parser.parse_args(call_args[1:])

        # print help if requested, or if no arguments
        if self.options.help or not positional_arguments:
            self.parser.print_help()
            print '\nActions and Arguments:'
            for (_, _, help) in self.valid_actions_with_help:
                if help:
                     print '    %s' % (help[0])
                     for line in help[1:]:
                        print '      %s' % (line,)
            return

        self.action = positional_arguments[0]
        self.arguments = positional_arguments[1:]

        # set the logging level and text for this program's logging
        self.log_prefix = ("","(DRY_RUN) ")[self.options.dry_run]
        self.logging_console_handler.setLevel( logging._levelNames[self.options.log_level.upper()] )

        # validation of options and action
        self.validate_plugin_patterns()
        if self.options.delete and self.options.unlink:
            raise DawnException('ERROR: you can specify at most one of --delete and --unlink')
        if (self.action not in self.valid_actions.keys()):
            raise DawnException('ERROR: action "%s" unrecognised (try --help)' % (self.action,))
        if self.options.keyring:
            self.options.keyring = os.path.realpath(os.path.abspath(os.path.expanduser(self.options.keyring)))
            if ((os.path.sep + '.ssh' + os.path.sep) in self.options.keyring) or self.options.keyring.endswith(('id_rsa','id_rsa.pub')):
                raise DawnException('ERROR: --keyring "%s" appears to be an ssh key. This is **WRONG**, it should be an Eclipse keyring.' % (self.options.keyring,))
            if not os.path.isfile(self.options.keyring):
                # sometimes, for reasons unknown, we temporarily can't see the file
                self.logger.warn('--keyring "%s" is not a valid filename, will look again in 2 seconds' % (self.options.keyring,))
                time.sleep(2)
                if not os.path.isfile(self.options.keyring):
                    raise DawnException('ERROR: --keyring "%s" is not a valid filename' % (self.options.keyring,))
            if not os.access(self.options.keyring, os.R_OK):
                # sometimes, for reasons unknown, we temporarily can't read the file
                self.logger.warn('current user does not have read access to --keyring "%s", will look again in 2 seconds' % (self.options.keyring,))
                time.sleep(2)
                if not os.access(self.options.keyring, os.R_OK):
                    raise DawnException('ERROR: current user does not have read access to --keyring "%s"' % (self.options.keyring,))
        if self.options.delete and self.action not in ('setup', 'materialize'):
            raise DawnException('ERROR: the --delete option cannot be specified with action "%s"' % (self.action))
        if self.options.system_property:
            if any((keyval.find('=') == -1) for keyval in self.options.system_property):
                raise DawnException('ERROR: the -D option must specify a property and value as "key=value"')
        else:
            self.options.system_property = []  # use [] rather than None so we can iterate over it
        if not self.options.jvmargs:
            self.options.jvmargs = []  # use [] rather than None so we can iterate over it

        # validate workspace
        if self.options.workspace:
            if ' ' in self.options.workspace:
                raise DawnException('ERROR: the "--workspace" directory must not contain blanks')
            self.workspace_loc = os.path.realpath(os.path.abspath(os.path.expanduser(self.options.workspace)))
        elif not self.workspace_loc:
            raise DawnException('ERROR: the "--workspace" option must be specified, unless you run this script from an existing workspace')
        self.workspace_git_loc = (self.workspace_loc and os.path.isdir( self.workspace_loc + '_git' ) and (self.workspace_loc + '_git')) or None

        # delete previous workspace as required
        if self.options.delete:
            self.delete_directory(self.workspace_loc, "workspace directory")
            self.delete_directory(self.workspace_git_loc, "workspace_git directory")
        elif self.options.unlink:
            self.unlink_workspace()

        # define proxy if not already defined  (proxy_name not in os.environ) or (not os.environ[proxy_name].strip())
        if self.options.keep_proxy:
            for env_name in ('http_proxy', 'https_proxy', 'no_proxy'):
                if env_name not in os.environ:
                    self.logger.debug('Using existing %s (unset)' % (env_name,))
                else:
                    self.logger.debug('Using existing %s=%s' % (env_name, os.environ[env_name]))
        else:
            fqdn = socket.getfqdn()
            if fqdn.endswith('.diamond.ac.uk'):
                proxy_value = 'wwwcache.rl.ac.uk:8080'
                no_proxy_value = '127.0.0.1,localhost,.diamond.ac.uk,*.diamond.ac.uk'
            elif fqdn.endswith('.esrf.fr'):
                proxy_value = 'proxy.esrf.fr:3128'
                no_proxy_value = '127.0.0.1,localhost'
            else:
                proxy_value = ''
                no_proxy_value = ''
            for env_name, env_value in (('http_proxy', 'http://'+proxy_value if proxy_value else ''),
                                        ('https_proxy', 'https://'+proxy_value if proxy_value else ''),
                                        ('no_proxy', no_proxy_value)):
                if env_name not in os.environ:
                    old_value = None  # indicates unset
                else:
                    old_value = os.environ[env_name].strip()
                if env_value:
                    if old_value:
                        self.logger.debug('Setting %s=%s (previously: %s)' % (env_name, env_value, old_value))
                    elif old_value is None:
                        self.logger.debug('Setting %s=%s (previously unset)' % (env_name, env_value,))
                    else:
                        self.logger.debug('Setting %s=%s (previously null)' % (env_name, env_value,))
                    os.environ[env_name] = env_value
                else:
                    if old_value:
                        self.logger.debug('No new value found for %s (left as: %s)' % (env_name, old_value))
                    elif old_value is None:
                        self.logger.debug('No new value found for %s (left unset)' % (env_name,))
                    else:
                        self.logger.debug('No new value found for %s (left null)' % (env_name,))

        # get some file locations (even though they might not be needed) 
        self.script_file_path = os.path.expanduser(self.options.script_file)
        if not os.path.isabs(self.script_file_path):
           self.script_file_path = os.path.abspath(os.path.join(self.workspace_loc, self.script_file_path))
        self.materialize_properties_path = os.path.expanduser(self.options.materialize_properties_file)
        if not os.path.isabs(self.materialize_properties_path):
           self.materialize_properties_path = os.path.abspath(os.path.join(self.workspace_loc, self.materialize_properties_path))

        # invoke funtion to perform the requested action
        action_handler = self.valid_actions[self.action]
        if action_handler:
            exit_code = action_handler(target=self.action)
        else:
            exit_code = getattr(self, 'action_'+self.action.replace('.','_').replace('-','_'))()

        end_time = datetime.datetime.now()
        run_time = end_time - start_time
        seconds = (run_time.days * 86400) + run_time.seconds
        hours, remainder = divmod(seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        self.logger.info('%sTotal run time was %02d:%02d:%02d' % (self.log_prefix, hours, minutes, seconds))
        return exit_code

###############################################################################
# Command line processing                                                     #
###############################################################################

if __name__ == '__main__':
    dawn = DawnManager()
    try:
        sys.exit(dawn.main(sys.argv))
    except DawnException, e:
        print e
        sys.exit(3)
    except KeyboardInterrupt:
        if len(sys.argv) > 1:
            print "\nOperation (%s) interrupted and will be abandoned." % ' '.join(sys.argv[1:])
        else:
            print "\nOperation interrupted and will be abandoned"
        sys.exit(3)

