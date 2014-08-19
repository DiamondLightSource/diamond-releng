#!/usr/bin/env python
# -*- encoding=utf8 -*-
'''
Runs on the Jenkins slave (always a Linux machine), and dispatches Squish tests on either itself, or another machine (typically a VM, possibly a different platform)

Expects the following environment variables:
    squish_linux32_zip / squish_linux64_zip / squish_win32_zip / squish_win64_zip - location of the Squish software
    (when running under Jenkins, these are defined in jenkins.control/properties/Common-environment-variables.properties

The Jenkins slave starts off like this:
    ${WORKSPACE}/artifacts_to_test/    (should be set up by Jenkins prior to this script running)
        <application>.zip              (this is the GUI part of the application for testing with Squish, e.g. for GDA it's the client)
        <other application stuff>.zip  (e.g. for GDA, this is the servers)
        squish_tests.zip               (the actual tests)
    ${WORKSPACE}/squish_framework/     (set up by this script)
        squish_control.zip
        squish-${squish_version}-java-${squish_platform}.zip
        epd_free-${epd_free_version}-${epd_platform}.sh (or ./msi)
    ${scratch}/squish_results/
        initially empty

The Squish host is initialized with these directories, if it is a different machine to the Jenkins slave (e.g., a VM):
    ${scratch}/artifacts_to_test/
        rysnc'd from the Jenkins slave
    ${scratch}/squish_framework/ 
        rysnc'd from the Jenkins slave

The Squish host is initialized with these directories:
    ${scratch}/aut/ (the name is kept short so that the path length on Windows is not too long)
        unzipped <application>.zip
    ${scratch}/aut_other/
        unzipped <other application stuff>.zip
    ${scratch}/squish_tmp/
        /squish/
            unzipped squish_framework/squish-${squish_version}-java-${squish_platform}.zip
        /squish_control/
            unzipped squish_control.zip
        /squish_tests/
            unzipped squish_tests.zip
    ${scratch}/squish_results/
        initially empty
    ${scratch}/squish_workspaces/
        initially empty
'''

from __future__ import print_function

import errno
import os
import os.path, ntpath, posixpath
import platform
import re
import socket
import subprocess
import time
import zipfile

def run_cmd(cmd, cwd=None, trace=True, output=True):
    """ Open a new subprocess, and sends a command string to it. Return the output to the caller.
    """

    if trace:
        print("Issuing: %s" % cmd)
    stdout_lines = []
    stderr_lines = []
    shell = subprocess.Popen(cmd, cwd=cwd, shell=True, universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for line in shell.stdout:
        stdout_lines.append(line.rstrip())
    for line in shell.stderr:
        stderr_lines.append(line.rstrip())
    shell.wait()
    if shell.returncode or stderr_lines:
        print("\nERROR: Command failed. Return code = %s" % shell.returncode)
    if shell.returncode or stderr_lines:
        if stdout_lines:
            print("stdout <<START")
            for line in stdout_lines:
                print(line)
            print("END>>")
        if stderr_lines:
            print("stderr <<START")
            for line in stderr_lines:
                print(line)
            print("END>>")
        print()
    elif output:
        if stdout_lines:
            for line in stdout_lines:
                print(line)
            print()
    return (shell.returncode, stdout_lines, stderr_lines)

#=====================================================================================================================#
#=====================================================================================================================#

class SquishTestSetupError(Exception):
    pass


class SquishTestManager():
    ''' Controls the environment for running Squish tests, comprising:
            A Jenkins slave, which controls the process
            A Squish host, which runs the tests
                might or might not be the same machine as the Jenkins slave
                might or might not be a virtual machine
    '''

    def __init__(self, squish_hostname=None, squish_platform=None, squish_VMname=None, use_epdfree=False, use_JRE=True, jenkins_workspace=None):
        ''' if this Squish host is *not* the same machine as the Jenkins slave which launches it:
                squish_hostname:   network name or address of Squish host
                squish_platform:   platform of Squish host (linux32/linux64/win32/win64)
                squish_VMname:     Virtual Machine name (can be None)
            in all cases:
                use_JRE:           use the JRE bundled with the RCP application
                jenkins_workspace: path to Jenkins workspace
        '''
        assert bool(squish_hostname) == bool(squish_platform)  # either both or neither must be specified
        assert jenkins_workspace  # must be specified

        if squish_hostname:
            self.squish_hostname = squish_hostname
            self.squish_platform = squish_platform
            self.squishHostIsJenkins = False
        else:  # None means the current machine
            self.squish_hostname = socket.getfqdn()
            self.squish_platform = {'linux':'linux', 'windows':'win'}[platform.system().lower()] + ('32','64')[platform.machine().endswith('64')]
            self.squishHostIsJenkins = True

        if self.squish_platform.startswith('linux'):
            self.squish_path = posixpath
            self.squish_scratch = self.squish_path.abspath('/scratch')
            self.squish_isLinux = True
            self.squish_isWin = False
        elif self.squish_platform.startswith('win'):
            self.squish_path = ntpath
            self.squish_scratch = self.squish_path.abspath('C:/scratch')
            self.squish_isLinux = False
            self.squish_isWin = True

        if squish_VMname:
            assert not self.squishHostIsJenkins  # if the Squish Host is a VM, it must be a different machine to the Jenkins slave
        self.squish_VMname = squish_VMname

        self.use_epdfree = use_epdfree
        self.use_JRE = use_JRE
        assert self.squish_path.isabs(jenkins_workspace)
        self.jenkins_workspace = jenkins_workspace

        # set names of special directories on the Squish host
        for dirname in ('aut', 'aut_other', 'squish_tmp', 'squish_results', 'squish_workspaces'):
            setattr(self, dirname+'_abspath', self.squish_path.abspath(self.squish_path.join(self.squish_scratch, dirname)))
        for dirname in ('squish_framework', 'artifacts_to_test'):
            # these directory names are different when this Squish host is the same machine as the Jenkins slave which launches it
            if self.squishHostIsJenkins:
                setattr(self, dirname+'_abspath', os.path.join(self.jenkins_workspace, dirname))
            else:
                setattr(self, dirname+'_abspath', self.squish_path.join(self.squish_scratch, dirname))

        self.ssh_options = '-o LogLevel=quiet -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -F /dev/null -o UserKnownHostsFile=/dev/null'
        if self.squish_VMname:
            # VMs have a specific user and password
            self.ssh_options += ' -o User=tester -o IdentityFile=~/.ssh/id_rsa-squish-vm-host'

    def specify_application(self, aut_name, aut_zip_pattern):
        self.aut_name = aut_name
        self.aut_zip_pattern = aut_zip_pattern

#=====================================================================================================================#

    def jenkins_slave_setup(self):
        ''' Generate the shell commands to:
                On the Jenkins slave, set up ${WORKSPACE}/squish_framework/
                rsync from the Jenkins slave to the Squish host (if they are different machines)
                On the Squish host, unzip the zip files
        '''

        # verify that the squish tests, and the application to test, are present in the workspace
        jenkins_artifacts_to_test_abspath = os.path.abspath(os.path.join(self.jenkins_workspace, 'artifacts_to_test'))
        if not os.path.isfile(os.path.join(jenkins_artifacts_to_test_abspath, 'squish_tests.zip')):
            raise SquishTestSetupError('ERROR: file does not exist: ' + os.path.join(jenkins_artifacts_to_test_abspath, 'squish_tests.zip'))
        self.aut_zip_name = None
        self.aut_other_zip_names = []
        for artifact in sorted(os.listdir(jenkins_artifacts_to_test_abspath)):
            if artifact == 'squish_tests.zip':
                continue
            if artifact.endswith('.zip'):
                if re.match(self.aut_zip_pattern, artifact):
                    if self.aut_zip_name:  # if we have already found it
                        raise SquishTestSetupError('ERROR: more than one .zip matched the pattern for the application ("{}") - found {} and {}'.format
                                                   (self.aut_zip_pattern, self.aut_zip_name, artifact))
                    self.aut_zip_name = artifact
                else:
                    self.aut_other_zip_names.append(artifact)
        if not self.aut_zip_name:
            raise SquishTestSetupError('ERROR: no .zip matched the pattern for the application ("{}")'.format(self.aut_zip_pattern))

        jenkins_squish_framework_abspath = os.path.abspath(os.path.join(self.jenkins_workspace, 'squish_framework'))
        if not os.path.isdir(jenkins_squish_framework_abspath):
            os.makedirs(jenkins_squish_framework_abspath)

        ### Squish
        # copy the squish zip to the Jenkins slave workspace
        squish_zip_origin = os.environ['squish_' + self.squish_platform + '_zip']
        if not os.path.isfile(squish_zip_origin):
            raise SquishTestSetupError('ERROR: file does not exist: ' + squish_zip_origin)
        squish_zip_name = os.path.basename(squish_zip_origin)
        run_cmd('rsync -e "ssh {}" -itv {} {}/'.format(self.ssh_options, squish_zip_origin, jenkins_squish_framework_abspath))

        # get the name of the directory that squish expands into
        with zipfile.ZipFile(os.path.join(jenkins_squish_framework_abspath, squish_zip_name), 'r') as squishzip:
            namelist = squishzip.namelist()
            direct_descendents_dirs = [filename for filename in namelist if (filename.count('/') == 1) and filename.endswith('/')]
            direct_descendents_files = [filename for filename in namelist if (filename.count('/') == 0)]
        if (len(direct_descendents_dirs) != 1) or (len(direct_descendents_files) != 0):
            raise SquishTestSetupError('ERROR: {} does not contain exactly one directory; instead has directories: {}, files: {}'.format
                                       (squish_zip_name, direct_descendents_dirs, direct_descendents_files))
        self.squish_abspath = self.squish_path.join(self.squish_tmp_abspath, 'squish', direct_descendents_dirs[0].rstrip(self.squish_path.sep))

        ### EPD
        # copy the EPD free installer (if one exists for the Squish platform) to the Jenkins slave workspace
        if self.use_epdfree:
            epdfree_installer_origin = os.environ['epd_free_' + self.squish_platform + '_installer']
            if epdfree_installer_origin:
                if not os.path.isfile(epdfree_installer_origin):
                    raise SquishTestSetupError('ERROR: file does not exist: ' + epdfree_installer_origin)
                epdfree_installer_name = os.path.basename(epdfree_installer_origin)
                run_cmd('rsync -e "ssh {}" -itv {} {}/'.format(self.ssh_options, epdfree_installer_origin, jenkins_squish_framework_abspath))

        ### squish_control
        # zip the squish_control directory
        for filename in ('squish_control.zip', 'squishrun.sh'):
            try:
                os.remove(os.path.join(jenkins_squish_framework_abspath, filename))
            except OSError as fault:
                if fault.errno == errno.ENOENT:  # No such file or directory
                    pass
                else:
                    raise
        run_cmd('cd {}/diamond-releng.git/diamond.releng.squish && zip -rq {}/squish_control.zip .'.format(self.jenkins_workspace, jenkins_squish_framework_abspath))

        ### Application under test
        # get the name of the directory that the application expands into
        with zipfile.ZipFile(os.path.join(jenkins_artifacts_to_test_abspath, self.aut_zip_name), 'r') as autzip:
            namelist = autzip.namelist()
            direct_descendents_dirs = [filename for filename in namelist if (filename.count('/') == 1) and filename.endswith('/')]
            direct_descendents_files = [filename for filename in namelist if (filename.count('/') == 0)]
        if (len(direct_descendents_dirs) != 1) or (len(direct_descendents_files) != 0):
            raise SquishTestSetupError('ERROR: {} does not contain exactly one directory; instead has directories: {}, files: {}'.format
                                       (self.aut_zip_name, direct_descendents_dirs, direct_descendents_files))
        self.guidir_abspath = self.squish_path.join(self.aut_abspath, direct_descendents_dirs[0].rstrip(self.squish_path.sep))
        if self.use_JRE:
            java = direct_descendents_dirs[0]+'jre/bin/java'
            if java not in namelist:
                raise SquishTestSetupError('ERROR: {} does not contain a JRE: expected {}'.format(self.aut_zip_name, java))
            self.jredir_abspath = self.squish_path.join(self.aut_abspath, direct_descendents_dirs[0], 'jre')

        ### generate the scripts to run on the Squish host
        with open(os.path.join(jenkins_squish_framework_abspath, 'squishhostsetup.sh'), 'w') as script:
            for part in (self.squish_host_initialize_script,
                         self.squish_host_unzip_script,):
                print(part(), file=script)
        with open(os.path.join(jenkins_squish_framework_abspath, 'squishhostrun.sh'), 'w') as script:
            for part in (self.squish_host_setup_display,
                         self.squish_host_setup_squish,
                         self.squish_host_runtests_script,):
                print(part(), file=script)
        if self.squish_isWin:
            os.rename( os.path.join(jenkins_squish_framework_abspath, 'squishhostsetup.sh'),
                       os.path.join(jenkins_squish_framework_abspath, 'squishhostsetup.bat') )
            os.rename( os.path.join(jenkins_squish_framework_abspath, 'squishhostrun.sh'),
                       os.path.join(jenkins_squish_framework_abspath, 'squishhostrun.bat') )

        ### generate the script to run on the Jenkins slave, after the Squish host has completed
        with open(os.path.join(jenkins_squish_framework_abspath, 'jenkinswrapup.sh'), 'w') as script:
            print(self.jenkins_post_processing_script(), file=script)
            if self.squish_VMname:
                print('vmrun -T ws suspend ' + self.squish_VMname, file=script)
                print('vmrun -T ws list', file=script)

        # if the Squish host is a virtual machine, start it
        if self.squish_VMname:
            print(time.strftime("%a, %Y/%m/%d %H:%M:%S"), 'Listing snapshots and running VMs before anything else happens (this may help debug a failed build)')
            run_cmd('vmrun -T ws listSnapshots ' + self.squish_VMname)
            run_cmd('vmrun -T ws list')
            run_cmd('vmrun -T ws revertToSnapshot ' + self.squish_VMname + ' base')
            run_cmd('vmrun -T ws list')
            nice_setting_vmrun = os.environ.get('nice_setting_vmrun', '')
            vmrun = 'vmrun'
            if nice_setting_vmrun:
                vmrun='nice -n ' + nice_setting_vmrun + ' vmrun'
            else:
                vmrun = 'vmrun'
            print(time.strftime("%a, %Y/%m/%d %H:%M:%S"), 'Starting VM ...')
            run_cmd('vmrun -T ws start ' + self.squish_VMname + ' nogui')
            run_cmd('vmrun -T ws list')
            print('VM can be stopped with: "vmrun -T ws stop ' + self.squish_VMname + '"')

        # copy everything to the Squish Host (if it is not the same machine as the Jenkins slave)
        if not self.squishHostIsJenkins:
            run_cmd('rsync -e "ssh {}" -irtv {}/ {}:{}/'.format(self.ssh_options,
                jenkins_squish_framework_abspath,
                self.squish_hostname, self.squish_framework_abspath))
            run_cmd('rsync -e "ssh {}" -irtv {}/ {}:{}/'.format(self.ssh_options,
                jenkins_artifacts_to_test_abspath,
                self.squish_hostname, self.artifacts_to_test_abspath))

        # command to run the commands on the Squish host
        with open(os.path.join(jenkins_squish_framework_abspath, 'squishhosttrigger.sh'), 'w') as script:
            if self.squishHostIsJenkins:
                print('. ' + os.path.join(jenkins_squish_framework_abspath, 'squishhostsetup.sh'), file=script)
                print('. ' + os.path.join(jenkins_squish_framework_abspath, 'squishhostrun.sh'), file=script)
            else:
                # the {self.squish_scratch}/log path is referenced in the VMs via "tail --retry --follow=name /scratch/log"
                print('ssh {} {} \'/bin/bash {} 2>&1 | tee {}/log\''.format(self.ssh_options, self.squish_hostname,
                    self.squish_path.join(self.squish_framework_abspath, 'squishhostsetup.sh'), self.squish_scratch), file=script)
                print('ssh {} {} \'/bin/bash {} 2>&1 | tee {}/log\''.format(self.ssh_options, self.squish_hostname,
                    self.squish_path.join(self.squish_framework_abspath, 'squishhostrun.sh'), self.squish_scratch), file=script)

        return  # at this point, the Jenkins slave does ". ${WORKSPACE}/squish_framework/squishhosttrigger.sh"

        # generate commands to run on the Squish Host, once everything required has been copied over
        # CASE 1 - Squish host is the same machine as the Jenkins slave, and is Linux
        # CASE 2 - Squish host is different to the Jenkins slave, and is Linux
        # CASE 3 - Squish host is different to the Jenkins slave, and is Windows

#=====================================================================================================================#

    def squish_host_initialize_script(self):
        '''
        returns a script to run on the Squish host, which
            deletes any working directories from a previous test run
            creates and initializes working directories for a new test run
        '''

        if self.squish_isLinux:
            return '''
for dir in {}; do
    if [[ -e "${{dir}}/" ]]; then
        chmod -R ug+w ${{dir}}/
        rm -rf ${{dir}}/
    fi
    mkdir -v ${{dir}}/
done
'''.format(' '.join([self.aut_abspath,
                     self.aut_other_abspath,
                     self.squish_tmp_abspath,
                     self.squish_results_abspath,
                     self.squish_workspaces_abspath,
                     self.squish_path.join(self.squish_scratch, 'workspace'),
                     ]))
        elif self.squish_isWin:
            raise NotImplementedError
        else:
            assert False

#=====================================================================================================================#

    def squish_host_unzip_script(self):
        '''
        returns a script to run on the Squish host, which
            unzips the application to test, the squish framework, and the squish tests
        '''

        if self.squish_isLinux:
            return '''
unzip -q -d {aut} {artifacts_to_test}/{aut_zip_name}
for zip in {aut_other_zip_names}; do
    unzip -q -d {aut_other} {artifacts_to_test}/${{zip}}
done
unzip -q -d {squish_tmp}/squish/ {squish_framework}/squish-*-java-*.zip
unzip -q -d {squish_tmp}/squish_control/ {squish_framework}/squish_control.zip
unzip -q -d {squish_tmp}/squish_tests/ {artifacts_to_test}/squish_tests.zip
'''.format(aut=self.aut_abspath,
           aut_other=self.aut_other_abspath,
           artifacts_to_test=self.artifacts_to_test_abspath,
           aut_zip_name=self.aut_zip_name,
           aut_other_zip_names=''.join(self.aut_other_zip_names),
           squish_tmp=self.squish_tmp_abspath,
           squish_framework=self.squish_framework_abspath)
        elif self.squish_isWin:
            raise NotImplementedError
        else:
            assert False

#=====================================================================================================================#

    def squish_host_setup_display(self):
        '''
        returns a script to run on the Squish host, which
            sets up the environment for running the tests
        '''

        if self.squish_isLinux:
            script = '''#!/bin/bash
set -o posix # posix mode so that error setting inherit to subshells
set -euvx # error, unset, verbose and echo
'''
            # There are some incompatibilities between the Unity app menu and Eclipse.
            # While in general it works mostly ok with newer Eclipse, there are still 
            # strange occurrences, such as random menu order changes. See:
            # https://bugs.launchpad.net/ubuntu/+source/appmenu-gtk/+bug/660314,
            # https://bugs.eclipse.org/bugs/show_bug.cgi?id=330563
            # https://bugs.launchpad.net/eclipse/+bug/618587
            script += '''
echo "current value of $""DISPLAY=${DISPLAY:-}"
if [[ "${DISPLAY:-}" != ":0.0" ]]; then
    # always display on local screen
    DISPLAY=':0.0'
    echo "value was set to $""DISPLAY=${DISPLAY}"
fi
export DISPLAY
export UBUNTU_MENUPROXY=0
'''

        return script

#=====================================================================================================================#

    def squish_host_setup_java(self):
        '''
        returns a script to run on the Squish host, which
            sets up the java environment
        '''

        if self.squish_isLinux:
            if self.use_JRE:
                return '''
export JAVA_HOME={jredir}
export java={jredir}/bin/java
export JRE_DIR={jredir}
export PATH={jredir}/bin:${{PATH:-}}

'''.format(jredir=self.jredir_abspath)
            else:
                # just use the native java, or whatever has been set up by diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh
                return '''
export java=java
if [[ -d "${JAVA_HOME}/jre" ]]; then
    # java is a JDK, point to the JRE bundled with it
    export JRE_DIR=${JAVA_HOME}/jre
else
    # java is a JRE
    export JRE_DIR=${JAVA_HOME}
fi

'''
        elif self.squish_isWin:
            raise NotImplementedError
        else:
            assert False

#=====================================================================================================================#

    def squish_host_setup_squish(self):
        '''
        returns a script to run on the Squish host, which
            sets up Squish
        '''

        if self.squish_isLinux:
            return self.squish_host_setup_java() + '''
# Initialize application and then make application directory read-only
{guidir}/{aut_name} -initialize
chmod -R a-w {guidir}/

# This is essentially the command that is run by the UI setup in Squish to create the magic squishrt.jar
java_version=`"${{java}}" -version 2>&1 | grep 'java version' | sed '-es,[^"]*"\\([^"]*\)",\\1,'`
"${{java}}" -classpath "{squish}/lib/squishjava.jar:{squish}/lib/bcel.jar" com.froglogic.squish.awt.FixMethod \
  "${{JRE_DIR}}/lib/rt.jar:{squish}/lib/squishjava.jar" "{squish}/lib/squishrt.jar"

# Copy the Squish license file
if [[ -f "${{SQUISH_LICENSE_FILE}}" ]]; then
  squish_license_filename=$(basename ${{SQUISH_LICENSE_FILE}})
  if [[ ! -f "~/${{squish_license_filename}}" ]]; then
    if [[ -f "{squish_tmp}/squish_control//${{squish_license_filename}}" ]]; then
      cp -pv "{squish_tmp}/squish_control/${{squish_license_filename}}" ~/${{squish_license_filename}}
    fi
  fi
fi
{squish}/bin/squishserver --config setJavaVM "$java" 
{squish}/bin/squishserver --config setJavaVersion "$java_version"
{squish}/bin/squishserver --config setJavaHookMethod "jvm"
{squish}/bin/squishserver --config setLibJVM "`find ${{JRE_DIR}} -name libjvm.so | head -1`"
{squish}/bin/squishserver --config addAUT {aut_name} {guidir}
{squish}/bin/squishserver --config setAUTTimeout 120

# Some tests (namely those using P2, such as the P2 update tests), need the configuration writeable,
# therefore export AUT_DIR so that configuration and p2 directories can be copied out
export AUT_DIR={guidir}
'''.format(squish_tmp=self.squish_tmp_abspath,
           squish=self.squish_abspath,
           aut_name=self.aut_name,
           guidir=self.guidir_abspath)
        elif self.squish_isWin:
            raise NotImplementedError
        else:
            assert False

#=====================================================================================================================#

    def squish_host_runtests_script(self):
        '''
        returns a script to run the tests on the Squish host
        '''

        # commands to start the squish server
        if self.squish_isLinux:
            script = '''
echo "$(date +"%a %d/%b/%Y %H:%M:%S") start squish server"
({squish}/bin/squishserver > {results}/squish_server.log 2>&1) &
squish_server_pid=$!

'''.format(squish=self.squish_abspath, results=self.squish_results_abspath)
        elif self.squish_isWin:
            raise NotImplementedError

        # get the names of the test suites available - directories named "suite_* one level down in the directory tree
        squish_suite_names_to_include = os.environ.get('squish_suite_names_to_include', '').strip()
        if squish_suite_names_to_include:
            squish_suite_names_to_include = map(str.strip, squish_suite_names_to_include.split(','))
        squish_suite_names_to_exclude = os.environ.get('squish_suite_names_to_exclude', '').strip()
        if squish_suite_names_to_exclude:
            squish_suite_names_to_exclude = map(str.strip, squish_suite_names_to_exclude.split(','))
            script += '''
# selecting suites to run based on:
#    squish_suite_names_to_include = {include}
#    squish_suite_names_to_exclude = {exclude}
'''.format(include=squish_suite_names_to_include,
           exclude=squish_suite_names_to_exclude)
        # commands to run the tests
        current_collection = None
        with zipfile.ZipFile(os.path.abspath(os.path.join(self.jenkins_workspace, 'artifacts_to_test', 'squish_tests.zip')), 'r') as testszip:
            suites_all = sorted(filename for filename in testszip.namelist() if (filename.count('/') == 2) and filename.endswith('/'))
            for filename in suites_all:
                (collection, suite) = filename.split('/')[0:2]
                if suite.startswith('suite_'):
                    # got a suite, see if we want to run it
                    run_suite = not bool(squish_suite_names_to_include)  # if no include list, then run everything
                    for pattern in squish_suite_names_to_include:
                        if re.match('^'+pattern+'$', suite):
                            run_suite = True
                            break
                    for pattern in squish_suite_names_to_exclude:  # if no exclude list, then run everything previously included
                        if re.match('^'+pattern+'$', suite):
                            run_suite = False
                            break
                    if run_suite:
                        if self.squish_isLinux:
                            if collection != current_collection:
                                script += 'export SQUISH_SCRIPT_DIR={squish_tmp}/squish_tests/{collection}/global_scripts\n'.format(squish_tmp=self.squish_tmp_abspath, collection=collection)
                                current_collection == collection 
                            script += '''
echo "$(date +"%a %d/%b/%Y %H:%M:%S") running {collection}/{suite}"
START_TIME=$(date +%s)
({squish}/bin/squishrunner \
  --testsuite {squish_tmp}/squish_tests/{collection}/{suite} \
  --reportgen stdout \
  --reportgen xml2.1,{results}/report_{collection}_{suite}_xml2.1.xml  \
  --reportgen xmljunit,{results}/report_{collection}_{suite}_xmljunit.xml \
  --resultdir {results} \
  > {results}/squish_runner_{collection}_{suite}.log 2>&1) || true
END_TIME=$(date +%s)
RUN_TIME=$((${{END_TIME}}-${{START_TIME}}))
printf "Elapsed run time was %d:%02d ({suite})" $((${{RUN_TIME}} / 60)) $((${{RUN_TIME}} % 60))

'''.format(squish=self.squish_abspath,
           squish_tmp=self.squish_tmp_abspath,
           collection=collection,
           suite=suite,
           results=self.squish_results_abspath)

                        elif self.squish_isWin:
                            raise NotImplementedError
                        else:
                            assert False

        # commands to stop the squish server
        if self.squish_isLinux:
            script += '''
echo "$(date +"%a %d/%b/%Y %H:%M:%S") stop squish server"
{squish}/bin/squishserver --stop
wait $squish_server_pid
'''.format(squish=self.squish_abspath,
           squish_tmp=self.squish_tmp_abspath,
           results=self.squish_results_abspath)
        elif self.squish_isWin:
            raise NotImplementedError

        # zip up result ready to copy back, if necessary
        if not self.squishHostIsJenkins:
            if self.squish_isLinux:
                script += '''
# zip up result ready to copy back
(cd {results} && zip -r {squish_tmp}/squish_results.zip .)
'''.format(results=self.squish_results_abspath,
           squish_tmp=self.squish_tmp_abspath)
            elif self.squish_isWin:
                raise NotImplementedError

        return script

#=====================================================================================================================#

    def jenkins_post_processing_script(self):
        '''
        returns a script to run on Jenkins, to run after tests have been un on the Squish host
        '''

        post_processing_script = ''

        # copy squish_results into Jenkins workspace
        if self.squishHostIsJenkins:
            assert self.squish_isLinux
            post_processing_script += '''
cp -pr {results} {jenkins_workspace}/squish_results/
'''.format(results=self.squish_results_abspath,
           jenkins_workspace=self.jenkins_workspace)
        else:
            post_processing_script += '''
rsync -e "ssh {ssh_options}" -irtv {squish_hostname}:{tmp}/squish_results.zip {jenkins_workspace}/squish_results.zip
unzip -q -d {jenkins_workspace}/squish_results {jenkins_workspace}/squish_results.zip
'''.format(ssh_options=self.ssh_options,
           squish_hostname=self.squish_hostname,
           tmp=self.squish_tmp_abspath,
           jenkins_workspace=self.jenkins_workspace)

        # create HTML versions of result files. Note that the results files were in a different directory name when generated on the Squish host (hence --prefix)
        post_processing_script += '''
# create HTML versions of result files
cd {jenkins_workspace}/squish_results/
xml21files=$(find -name '*_xml2.1.xml' | cut -c 3- | sort)
python {jenkins_workspace}/diamond-releng.git/diamond.releng.squish/squishxml2html.py -v --dir {jenkins_workspace}/squish_results/ -i --prefix {results}/ ${{xml21files}}

'''.format(jenkins_workspace=self.jenkins_workspace,
           results=self.squish_results_abspath)

        return post_processing_script

#=====================================================================================================================#

