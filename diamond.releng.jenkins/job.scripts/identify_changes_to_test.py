#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
This program runs in the context of a specific GDA or DAWN release, which determines the repository branches that would normally be used

It takes a specification of a change or changes to test, defined by one or more of:
(1) A Gerrit topic or topics (which identify one or more changesets, typically in different repositories)
(2) A Gerrit changeset or changesets
(3) A repository/branch name to override the standard branch
If multiple specifications are provided, they need to be consistent with each other, obviously

We generate a script to apply the changes to the affected repositories

Testing notes:
   Set environment variables something like this:
      export WORKSPACE=~
      export gerrit_topic_1=GDA-1234
      export gerrit_change_1=123
      export repo_1_name=
      export repo_1_head=
      export repo_1_action=
      export gerrit_verified_option="don't post anything to Gerrit"
      export gerrit_verify_ancestors=true
   Create cquery-branches-file.txt by running some variant of the following command
      pewma.py --cquery.branches.file=${WORKSPACE}/artifacts_to_archive/cquery-branches-file.txt get-branches-expected gda 8.44

To understand this code, you need to look at the Gerrit REST API documentation
            and particularly at the format of the JSON objects that it returns

'''

from __future__ import absolute_import, division, print_function, unicode_literals

import cgi
import collections
import itertools
import json
import logging
import operator
import os
import os.path
import stat
import sys
import time
import urllib
import urllib2
import urlparse

MAX_TOPICS = 3  # a number >= the number of topic parameters in the Jenkins job
MAX_CHANGESETS = 6  # a number >= the number of change parameters in the Jenkins job
MAX_HEAD_OVERRIDES = 30  # a number >= the number of repo/branch parameters in the Jenkins job

# input files
artifacts_to_archive_DIR_PATH             = os.path.abspath(os.path.expanduser(os.path.join(os.environ['WORKSPACE'], 'artifacts_to_archive')))
CQUERY_BRANCHES_FILE                      = os.path.join(artifacts_to_archive_DIR_PATH, 'cquery-branches-file.txt')
# output files
CHANGES_UNDER_TEST_REPORT_FILE            = os.path.join(artifacts_to_archive_DIR_PATH, 'changes_under_test_report.txt')
PRE_MATERIALIZE_FUNCTION_FILE_PATH        = os.path.join(artifacts_to_archive_DIR_PATH, 'gerrit_pre.materialize.function.sh')
POST_MATERIALIZE_FUNCTION_FILE_PATH       = os.path.join(artifacts_to_archive_DIR_PATH, 'gerrit_post.materialize.function.sh')
NOTIFY_GERRIT_AT_START_FUNCTION_FILE_PATH = os.path.join(artifacts_to_archive_DIR_PATH, 'notify_to_gerrit_at_start.sh')
NOTIFY_GERRIT_AT_END_FUNCTION_FILE_PATH   = os.path.join(artifacts_to_archive_DIR_PATH, 'notify_to_gerrit_at_end.sh')
SET_JUNIT_OPTIONS_FILE_PATH               = os.path.join(artifacts_to_archive_DIR_PATH, 'gerrit_set.junit.options.sh')
CHANGE_OWNER_EMAIL_ADDRESSES_FILE_PATH    = os.path.join(artifacts_to_archive_DIR_PATH, 'change_owners_emails.txt')

GERRIT_HOST = 'gerrit.diamond.ac.uk'
GERRIT_ICON_HTML = '<img border="0" src="/plugin/gerrit-trigger/images/icon16.png" />'

# define module-wide logging
logger = logging.getLogger('identify_changes_to_test')  # global logger for this module
def setup_logging():
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s", "%Y-%m-%d %H:%M:%S")
    # create console handler
    logging_console_handler = logging.StreamHandler()
    logging_console_handler.setFormatter(formatter)
    logger.addHandler(logging_console_handler)
    logging_file_handler = logging.FileHandler(CHANGES_UNDER_TEST_REPORT_FILE, 'w')  # rewrite rather than default to append
    logging_file_handler.setFormatter(formatter)
    logger.addHandler(logging_file_handler)
    logger.setLevel(logging.INFO)
    # logger.setLevel(logging.DEBUG)


class RequestedChangesProcessor():

    def __init__(self):
        self.generated_header = ('### File generated ' + time.strftime("%a, %Y/%m/%d %H:%M:%S %z") +  # header line for files that we write
                                 ' (' + os.environ.get('BUILD_URL','$BUILD_URL:missing') + ')\n')
        setup_logging()
        self.logger = logger
        self.logger.info(self.generated_header.rstrip())

        self.gerrit_url_base = 'https://' + GERRIT_HOST + '/'  # when using the REST API, this is the base URL to use
        self.gerrit_url_browser = self.gerrit_url_base  # when generating links, this is the base URL to use
        self.gerrit_ssh_command = 'ssh -p %s %s' % (self.get_gerrit_ssh_port(self.gerrit_url_base), GERRIT_HOST)
        self.gerrit_verified_option = os.environ.get('gerrit_verified_option', 'don\'t post anything to Gerrit').strip().lower()
        self.gerrit_verify_ancestors = os.environ.get('gerrit_verify_ancestors', 'false').strip().lower() == 'true'
        self.errors_found = False

        # since the Gerrit REST API has been secured, then we need to use basic authentication
        self.gerrit_url_base += 'a/'
        handler = urllib2.HTTPBasicAuthHandler()
        handler.add_password('Gerrit Code Review', self.gerrit_url_base, *self.get_gerrit_http_username_password())
        opener = urllib2.build_opener(handler)
        urllib2.install_opener(opener)

    @staticmethod
    def get_gerrit_ssh_port(gerrit_url):
        ''' determines the port number that the Gerrit ssh daemon is running on (default:29418)
        '''

        url = urlparse.urljoin(gerrit_url, 'ssh_info')
        try:
            host_sshport = urllib2.urlopen(url).read()
        except (urllib2.HTTPError, urllib2.URLError) as err:
            raise Exception('Invalid response from Gerrit server reading %s: %s' % (url, err))
            return None
        return host_sshport.split()[1]

    @staticmethod
    def get_gerrit_http_username_password():
        ''' the token required to authenticate to Gerrit is stored in a file
            the file, in addition to comment and empty lines, contains a single line of the format
               username:password
        '''

        token_filename = os.path.abspath(os.path.expanduser('~/passwords/http-password_Gerrit_for-REST.txt'))
        assert os.path.isfile(token_filename)
        assert os.stat(token_filename).st_mode == stat.S_IRUSR + stat.S_IFREG  # permissions must be user-read + regular-file
        last_nonempty_line = ''
        with open(token_filename, 'r') as token_file:
            for line in token_file:  # standard OS terminator is converted to \n
                line = line.rstrip('\n')  # remove trailing newline
                if line:
                    last_nonempty_line = line
        if last_nonempty_line:
            return last_nonempty_line.split(':', 1)
        raise Exception('File %s appears empty' % token_filename)

    def get_expected_branch_for_repo(self, repo):
        """ For the specified repository, returns the branch that a specific CQuery would materialize
            (as previously extracted from a CQuery by pewma.py and written to a file)
        """

        if not hasattr(self, 'cquery_branches'):
            # read and save the contents of cquery-branches-file.txt, and never re-read
            with open(CQUERY_BRANCHES_FILE, 'r') as cquery_branches_file:
                self.cquery_branches = {}
                for line in cquery_branches_file:
                    line_cleaned = line.lstrip().rstrip()
                    if line_cleaned.startswith('#') or (not line_cleaned):  # comment or empty line
                        continue
                    (reponame, equals_sign, branch) = line_cleaned.partition('=')
                    if (not reponame) or (equals_sign != '=') or (not branch):
                        self.logger.error('Unexpected line format in %s: "%s"' % (CQUERY_BRANCHES_FILE, line))
                        continue
                    self.cquery_branches[reponame] = branch

        if not repo:
            return None  # caller not interested in a specific repo, but just wanted self.cquery_branches created
        else:
            return self.cquery_branches[repo]  # should never raise KeyError; something is badly wrong if the repo is not mentioned in the CQuery

    def get_override_branch_for_repo(self, repo):
        """ For the specified repository, returns an alternative point (branch or commit) to materialize, and an action (merge or checkout)
            (as specified via build parameters)
            Note that this only applies to repositories that do NOT have a Gerrit change under test
            (if they _do_ have a Gerrit change under test, then the change itself determines what branch is used)
        """

        if not hasattr(self, 'override_branches'):
            if repo is not None:
                # first call must always be the initialize call
                raise Exception('first call to get_override_branch_for_repo was for a specific repository (%s)' % repo)
            self.override_branches = {}
            # get any branch overrides specified (passed in environment variables - these are created by Jenkins from the build parameters)
            for i in range(1, MAX_HEAD_OVERRIDES+1):
                repo_parms = {}
                for parm_type in ('name', 'head', 'action'):
                        parm_name = 'repo_%s_%s' % (i, parm_type)
                        repo_parms[parm_type] = os.environ.get(parm_name, '').strip()
                # validate the action, and translate to a one-word form
                if repo_parms['action']:
                    for action in ('merge', 'checkout'):
                        if action in repo_parms['action']:
                            repo_parms['action'] = action
                            break
                    else:
                        self.logger.error('Build parameters repo_%s %s invalid: action not recognised' %
                                         (i, repo_parms))
                        self.errors_found = True
                        continue
                if any(repo_parms.itervalues()) and not repo_parms['action']:  # at least one, but not all, specified
                    repo_parms['action'] = 'merge'  # if the action not specified, default to "checkout"
                if all(repo_parms.itervalues()):  # all specified
                    if repo_parms['name'] not in self.cquery_branches:  # something has gone wrong somewhere
                        self.logger.critical('Internal error with repo naming: ' + repo_parms['name'] + ' not in ' + str(sorted(self.cquery_branches.keys())))
                        self.errors_found = True
                    else:
                        self.logger.info('Build parameters repo_%s %s specified branch/commit override' %
                                         (i, repo_parms))
                        self.override_branches[repo_parms['name']] = (repo_parms['head'], repo_parms['action'])
                elif any(repo_parms.itervalues()):  # at least one, but not all, specified
                    self.logger.error('Build parameters repo_%s %s invalid: either neither or all must be specified' %
                                     (i, repo_parms))
                    self.errors_found = True
        if not repo:
            return self.override_branches
        else:
            return self.override_branches.get(repo, None)

    def gerrit_REST_api(self, relative_url, accept404=False):
        ''' Call the Gerrit REST API
        '''

        url = self.gerrit_url_base + relative_url
        request = urllib2.Request(url, headers={'Accept': 'application/json', 'Accept-Charset': 'utf-8'})  # header specifies compact json, which is more efficient
        self.logger.debug('gerrit_REST_api retrieving: %s' % (url,))
        try:
            rest_json = urllib2.urlopen(request).read()
        except (urllib2.HTTPError) as err:
            if accept404 and (err.code == 404):
                self.logger.debug('Invalid response from Gerrit server reading %s: %s' % (url, err))
                return None
            self.logger.critical('Invalid response from Gerrit server reading %s: %s' % (url, err))
            return None
        gerrit_magic_prefix_line = ")]}'\n"
        if not rest_json[:len(gerrit_magic_prefix_line)] == gerrit_magic_prefix_line:
            self.logger.critical('Invalid response from Gerrit server reading %s: magic prefix line not found' % (url,))
            return None
        standard_json = json.loads(rest_json[len(gerrit_magic_prefix_line):])  # strip off the magic prefix line returned by Gerrit
        # self.logger.debug(json.dumps(standard_json, indent=2))
        return standard_json

    def get_change_owner_uploader_initials(self, ci):
        ''' Return an HTML fragment consisting of a change owner's initials, with their full name as hover text
            If the last uploader is a different person, include their details as well
        '''
        try:
            change_owner_fullname = ci['owner']['name']
            change_owner_initials = ''.join(map(lambda x: x[0], change_owner_fullname.split()))
            change_uploader_fullname = ci['revisions'].values()[0]['uploader']['name']
            if change_uploader_fullname == change_owner_fullname:
                return \
                    '(<span title="' + \
                    cgi.escape(change_owner_fullname, quote=True) + \
                    '">' + \
                    cgi.escape(change_owner_initials, quote=True) + \
                    '</span>)'
            change_uploader_initials = ''.join(map(lambda x: x[0], change_uploader_fullname.split()))
            return \
                '(<span title="Owner: ' + \
                cgi.escape(change_owner_fullname, quote=True) + ' / Uploader: ' + \
                cgi.escape(change_uploader_fullname, quote=True) + \
                '">' + \
                cgi.escape(change_owner_initials, quote=True) + '/' + \
                cgi.escape(change_uploader_initials, quote=True) + \
                '</span>)'
        except:
            return ''

    def get_change_summary(self, ci):
        ''' Return an HTML-escaped text fragment consisting of the repository name and the first part of the change subject (first line of commit)
            Used to form hover text on a Jenkins page
        '''
        try:
            subject = ci['subject']
            if len(subject) > 53:
                subject = subject[0:50] + '...'
            return cgi.escape('%s: %s' % (os.path.basename(ci['project']), subject), quote=True)
        except:
            return ''

    def get_change_uploader_email(self, ci):
        ''' Return the email address associated with a change owner
        '''
        try:
            return ci['revisions'].values()[0]['uploader']['email']
        except:
            return ''

    def get_changes_from_gerrit(self):
        ''' Queries Gerrit to get a list of ChangeInfo records for the changes to be tested
        '''

        self.changes_to_test = []  # this is a list of ChangeInfo entities
        self.jenkins_build_description = ''

        # Build the query URL for topic specified (passed in environment variables - these are created by Jenkins from the build parameters)
        for i in range(1, MAX_TOPICS+1):
            build_param_name = 'gerrit_topic_' + str(i)
            build_param_value = os.environ.get(build_param_name, '').strip()
            if not build_param_value:
                continue
            # ignore abandoned changes that are part of the topic (just like Gerrit does)
            # if an abandoned change is specified explicitly (rather than as part of a topic), then it's a user error if the change is abandoned
            url = 'changes/?q=topic:{%s}+-status:abandoned&o=CURRENT_REVISION&o=DETAILED_ACCOUNTS' % (urllib.quote(build_param_value),)
            changeinfos = self.gerrit_REST_api(url)
            if (not changeinfos) or (len(changeinfos) == 0):
                self.logger.error('Item "%s" does not exist (or is not visible to Jenkins)' % (url.partition('?')[2].partition('&')[0],))
                self.errors_found = True
                continue
            component_changes_description = ''
            for ci in sorted(changeinfos, key=lambda ci: os.path.basename(ci['project'])):  # there can be multiple changeinfos for a topic
                self.changes_to_test.append(ci)
                change_uploader_initials = self.get_change_owner_uploader_initials(ci)
                change_summary = self.get_change_summary(ci)
                self.logger.info('Build parameter %s=%s will test change "%s" in "%s", branch "%s", patch set "%s"' %
                                (build_param_name, build_param_value, ci['_number'], os.path.basename(ci['project']), ci['branch'], ci['revisions'].values()[0]['_number']))
                component_changes_description += (' <a href="%(gerrit_url)s#/c/%(change)s/%(patchset)s" title="%(summary)s" target="_blank">%(change)s,%(patchset)s</a>%(change_uploader_initials)s' %
                                                  {'gerrit_url': self.gerrit_url_browser, 'summary': change_summary,
                                                    'change': ci['_number'], 'patchset': ci['revisions'].values()[0]['_number'],
                                                    'change_uploader_initials': change_uploader_initials})
            self.jenkins_build_description += (GERRIT_ICON_HTML + ' topic <a href="%(gerrit_url)s#/q/topic:%(topic_quoted)s" target="_blank">%(topic)s</a><br>' %
                                               {'gerrit_url': self.gerrit_url_browser,
                                                'topic_quoted': urllib.quote(build_param_value),
                                                'topic': build_param_value})
            self.jenkins_build_description += '<span style="padding-left: 2em">(comprises</span> ' + component_changes_description.strip() + ')<br>'

        # Build the query URL for each change number specified (passed in environment variables - these are created by Jenkins from the build parameters)
        jenkins_build_description_changes = ''
        changes_specified_count = 0
        for i in range(1, MAX_CHANGESETS+1):
            build_param_name = 'gerrit_change_' + str(i)
            build_param_value = os.environ.get(build_param_name, '').strip()
            if not build_param_value:
                continue
            try:
                assert repr(int(build_param_value)) == build_param_value  # check that the change is numeric
            except (ValueError, AssertionError):
                self.logger.error('Build parameter %s=%s invalid (not numeric)' % (build_param_name, build_param_value))
                self.errors_found = True
                continue
            url = 'changes/?q=change:%s&o=CURRENT_REVISION&o=DETAILED_ACCOUNTS' % (urllib.quote(build_param_value),)
            changeinfos = self.gerrit_REST_api(url)  # there will be just one changeinfo for a single change
            if (not changeinfos) or (len(changeinfos) == 0):
                self.logger.error('Build parameter %s=%s, but item "%s" does not exist (or is not visible to Jenkins)' %
                                 (build_param_name, build_param_value, url.partition('?')[2].partition('&')[0],))
                self.errors_found = True
                continue
            assert len(changeinfos) == 1
            for ci in changeinfos:
                self.changes_to_test.append(ci)
                changes_specified_count += 1
                change_uploader_initials = self.get_change_owner_uploader_initials(ci)
                change_summary = self.get_change_summary(ci)
                self.logger.info('Build parameter %s=%s will test change "%s" in "%s", branch "%s", patch set "%s"' %
                                (build_param_name, build_param_value, ci['_number'], os.path.basename(ci['project']), ci['branch'], ci['revisions'].values()[0]['_number']))
                jenkins_build_description_changes += ('<a href="%(gerrit_url)s#/c/%(change)s/%(patchset)s" title="%(summary)s" target="_blank">%(change)s,%(patchset)s</a>%(change_uploader_initials)s ' %
                                                   {'gerrit_url': self.gerrit_url_browser, 'summary': change_summary,
                                                    'change': ci['_number'], 'patchset': ci['revisions'].values()[0]['_number'],
                                                    'change_uploader_initials': change_uploader_initials})
        if jenkins_build_description_changes:
            self.jenkins_build_description += (GERRIT_ICON_HTML +
                                               ' change' + (' ','s ')[bool(changes_specified_count > 1)] +
                                               jenkins_build_description_changes)

        if not self.changes_to_test:
            if self.errors_found:
                self.logger.error('Errors were found in the specification of the Gerrit changes to test - abandoning')
            else:
                self.logger.info('No changes from Gerrit were specified for testing')

    def process_changes_from_gerrit(self):
        ''' To understand this code, you need to look at the Gerrit REST API documentation
            and particularly at the format of the JSON objects that it returns
        '''

        # check that we didn't get any duplicated change numbers
        # if duplicates, remove all but the last occurrence, and proceed to further error checking, before exiting
        distinct_change_numbers = []
        duplicated_change_numbers = []
        changes_to_test_deduped = []  # this is a list of ChangeInfo entities
        for ci in self.changes_to_test:
            change_number = ci['_number']
            if change_number not in distinct_change_numbers:
                distinct_change_numbers.append(change_number)
                changes_to_test_deduped.append(ci)
            else:
                duplicated_change_numbers.append(change_number)
        assert len(self.changes_to_test) == len(changes_to_test_deduped) + len(duplicated_change_numbers)
        if duplicated_change_numbers:
            self.logger.error('The following change numbers were specified more than once: ' +
                              str(sorted(duplicated_change_numbers, key=int)))
            self.errors_found = True
            self.changes_to_test = changes_to_test_deduped

        # check that the changes to test are not already merged or abandoned
        for ci in self.changes_to_test:
            status = ci['status']
            if status not in ('NEW', 'DRAFT'):
                self.logger.error('Change "%s" in repository "%s" is not eligible for testing: status is "%s"' % (ci['_number'], os.path.basename(ci['project']), status))
                self.errors_found = True

        # check that all changes are on a branch compatible with this test job
        # if we have multiple changes specified in the same project (repository), check that they are all on the same branch
        # check that an override branch was not specified (the branch is determined by the Gerrit change, so must not be specified as an override as well)
        per_project_branches = {}  # this is a dictionary of project:set(branchnames)
        per_project_changes = {}  # this is a dictionary of project:list[ChangeInfos]
        for ci in self.changes_to_test:
            project = ci['project']
            per_project_branches.setdefault(project,set()).add(ci['branch'])
            per_project_changes.setdefault(project,[]).append(ci)
            expected_branch = self.get_expected_branch_for_repo(os.path.basename(project))  # basename required since repos are named something like gda/gda-core
            if not ((ci['branch'] == expected_branch) or ci['branch'].startswith(expected_branch + '-')):
                self.logger.error('Change "%s" in repository "%s" branch "%s" does not match the branch used by this test job ("%s")' %
                                  (ci['_number'], os.path.basename(project), ci['branch'], expected_branch))
                self.errors_found = True
        for (project, branches) in per_project_branches.iteritems():
            if len(branches) != 1:
                self.logger.error('Changes in repository "' + os.path.basename(project) + '" have inconsistent branches. ' +
                                  'Change/branch numbers specified: ' +
                                  str([str('%s/%s' % (ci['_number'], ci['branch'])) for ci in self.changes_to_test if ci['project'] == project]))
                self.errors_found = True
            if self.get_override_branch_for_repo(os.path.basename(project)):
                self.logger.error('For repository "' + os.path.basename(project) + '", changes to test were specified, but the branch to test was also specified')
                self.errors_found = True

        # it's possible that we have multiple changes to test in the same project (repository)
        # check that they are all in the same dependency chain, and identify which is the top of the chain - this is the change we need to fetch
        # check also that the dependency chain doesn't have more than one patchset for the same change
        # and finally, it really is better if all changes in the dependency change are the latest patchset for the change!
        self.changes_to_fetch = []  # a list of [ChangeInfos, RelatedChangeAndCommitInfo, ...], one per repository
        for (project, changes) in sorted(per_project_changes.iteritems()):
            assert changes  # there must be some changes to test in this repository, otherwise we would not be here
            change_patch_numbers_requested_to_test = [(ci['_number'], ci['revisions'].values()[0]['_number']) for ci in changes]  # [0] since we only requested the current revisions
            change_patch_numbers_requested_to_test_str = str([str('%s/%s' % (c,p)) for (c,p) in change_patch_numbers_requested_to_test]).replace("'","")
            if len(changes) != 1:
                self.logger.info('Checking that repository "' + os.path.basename(project) + '" changes ' + change_patch_numbers_requested_to_test_str + ' are related')

            # for all changes in this repository that were explicitly listed for testing, get all changes that are related
            # the related changes for a given change are in git commit order, from newest to oldest
            # if there are related changes, then the related changes chain includes the current change plus all related changes, both newer and older
            # however, if there are no related changes, then the related changes chain is empty (you might expect it to include the current change itself)
            # we ignore any related changes that are newer than the change explicitly listed for testing
            related_change_chains = []  # will be a list, each entry is either a list of related change records, or a len(1) list of a single ChangeInfo record if there were no related changes
            for ci in changes:
                url = 'changes/%s/revisions/current/related' % (ci['_number'],)
                relatedinfo = self.gerrit_REST_api(url)
                older_unmerged_related_changes = []  # the dependency chain of the current change - all unmerged related changes that are older than this change
                seen_current_change_in_related_chain = False
                seen_merged_change_older_than_current_change_in_related_chain = False
                for cr in relatedinfo['changes']:  # we're processing in order from newest to oldest; our change is somewhere in the chain
                    if not seen_current_change_in_related_chain:
                        if cr['_change_number'] == ci['_number']:
                            seen_current_change_in_related_chain = True
                        continue
                    if cr['status'] == 'MERGED':
                        seen_merged_change_older_than_current_change_in_related_chain = True
                    else:
                        older_unmerged_related_changes.append(cr)
                        if seen_merged_change_older_than_current_change_in_related_chain:
                            self.logger.critical('In "' + os.path.basename(project) + '" change ' + str(ci['_number']) + '/' + str(ci['revisions'].values()[0]['_number']) +
                                              ' has a older related change ' + str(cr['_change_number']) + '/' + str(cr['_revision_number']) +
                                              ' that is _not_ merged, but which has a descendant that _is_ merged - should be impossible. Check ' + url)
                            self.errors_found = True
                if relatedinfo['changes'] and (not seen_current_change_in_related_chain):
                    self.logger.critical('In "' + os.path.basename(project) + '" change ' + str(ci['_number']) + '/' + str(ci['revisions'].values()[0]['_number']) +
                                      ' didn\'t find change in the list of its own dependencies. Check ' + url)
                    self.errors_found = True

                if older_unmerged_related_changes:
                    unmerged_older_related_change_patch_numbers = [(cr['_change_number'], cr['_revision_number']) for cr in older_unmerged_related_changes]
                    unmerged_older_related_change_patch_numbers_str = str([str('%r/%r' % (c,p)) for (c,p) in unmerged_older_related_change_patch_numbers]).replace("'","")
                    self.logger.info('"' + os.path.basename(project) + '" change ' + str(ci['_number']) + '/' + str(ci['revisions'].values()[0]['_number']) +
                                     ' has older unmerged related changes: ' + unmerged_older_related_change_patch_numbers_str)
                    for cr in older_unmerged_related_changes:
                        if cr['_revision_number'] != cr['_current_revision_number']:
                            self.logger.error('In "' + os.path.basename(project) + '" change ' + str(ci['_number']) + '/' + str(ci['revisions'].values()[0]['_number']) +
                                              ' has a related change ' + str(cr['_change_number']) + '/' + str(cr['_revision_number']) +
                                              ' that is not current (latest patchset is ' + str(cr['_current_revision_number']) + ')')
                            self.errors_found = True
                            continue
                        if cr['status'] not in ('NEW', 'DRAFT'):
                            self.logger.error('Change "%s" in repository "%s" depends on related change "%s" that is not eligible for testing: status is "%s"' %
                                              (str(ci['_number']) + '/' + str(ci['revisions'].values()[0]['_number']), os.path.basename(project),
                                               str(cr['_change_number']) + '/' + str(cr['_revision_number']), cr['status']))
                            self.errors_found = True
                    related_change_chains.append([ci] + older_unmerged_related_changes)
                else:
                    related_change_chains.append([ci])

            assert len(related_change_chains) == len(changes)
            if self.errors_found:
                continue  # next repository

            # now we want to identify, out of the commits requested to be tested in this repository, the newest one
            # we also need to identify all commits (whether listed for testing or not) from the newest requested back to the branch head
            # for the test, we just need to fetch the newest commit (fetches all unmerged commits in the dependency chain)
            if len(related_change_chains) > 1:
                # we were asked to test multiple changes in the repository, check that they are all in the same chain, and identify the longest chain
                related_change_chains.sort(key=lambda c: len(c))
                tokenized_related_change_chains = []
                for chain in related_change_chains:
                    token = ''
                    for cr in chain[:0:-1]:  # go through the related change records (if any) from the end (newest) back to the first (the one after the ChangeInfo record)
                        token += '%s/%s##' % (cr['_change_number'], cr['_revision_number'])
                    token += '%s/%s##' % (chain[0]['_number'], chain[0]['revisions'].values()[0]['_number'])  # from the start (newest) of the chain, which is a ChangeInfo record
                    tokenized_related_change_chains.append(token)
                for item, next in itertools.izip(tokenized_related_change_chains, tokenized_related_change_chains[1:]):
                    if len(item) < len(next):
                        if item == next[:len(item)]:
                            continue
                    self.logger.error('Multiple changes in "' + os.path.basename(project) + '" were specified, but from unrelated commits ' +
                                      '(all commits to be tested must be from a single chain)')
                    self.errors_found = True
                    break  # only need to report this error once per repository
            change_chain_to_test = related_change_chains[-1]
            if self.errors_found:
                continue  # next repository

            # at this point, we know the patch numbers are good
            # "change_chain_to_test" is a list of either a single ChangeInfo record, or a ChangeInfo record plus related change records
            self.changes_to_fetch.append(change_chain_to_test)  # append result for this repository
            change_to_fetch_desc = 'In "%s", change to fetch is "%s/%s"' % (
                                    os.path.basename(project),
                                    self.changes_to_fetch[-1][0]['_number'],
                                    self.changes_to_fetch[-1][0]['revisions'].values()[0]['_number'])
            if len(change_chain_to_test) == 1:
                self.logger.info(change_to_fetch_desc)
            else:
                self.logger.info(change_to_fetch_desc +
                                 ' and also includes changes ' +
                                 str([str('%s/%s' % (cr['_change_number'], cr['_revision_number'])) for cr in change_chain_to_test[1:]]).replace("'",""))

        if self.errors_found:  # we have finished all parameter validation
            self.logger.error('Errors were found in the details of the Gerrit changes to test - abandoning')
            return 1

        # self.changes_to_fetch is a list of [ChangeInfo, [RelatedChangeAndCommitInfos, ...]
        # confirm that we have exactly 1 change to fetch per project
        projects_to_fetch = [ci[0]['project'] for ci in self.changes_to_fetch]
        assert len(projects_to_fetch) == len(set(projects_to_fetch))
        # sort the changes to apply in order of project
        self.changes_to_fetch.sort(key=lambda ci: os.path.basename(ci[0]['project']))  # sort on the project (repository)

    def write_pre_post_materialize_functions(self):
        ''' write the pre_materialize stage2 function into the script file
        '''

        if not (self.changes_to_test or self.get_override_branch_for_repo(None)):
            return  # no changes requested

        with open(PRE_MATERIALIZE_FUNCTION_FILE_PATH, 'w') as pre_materialize_script_file:
            pre_materialize_script_file.write(self.generated_header)
            pre_materialize_script_file.write('''\
pre_materialize_function_stage2_gerrit () {

    # Save errexit state (1=was not set, 0=was set)
    if [[ $- = *e* ]]; then
        olderrexit=0
    else
        olderrexit=1
    fi
    set -e  # Turn on errexit

''')
            if self.get_override_branch_for_repo(None):
                # post_materialize_script_file only written if we have non-Gerrit repos in which we are switching branches
                with open(POST_MATERIALIZE_FUNCTION_FILE_PATH, 'w') as post_materialize_script_file:
                    post_materialize_script_file.write(self.generated_header)
                    post_materialize_script_file.write('''\
post_materialize_function_gerrit () {

    # Save errexit state (1=was not set, 0=was set)
    if [[ $- = *e* ]]; then
        olderrexit=0
    else
        olderrexit=1
    fi
    set -e  # Turn on errexit

''')

            #=======================
            # write the pre_materialize function for Gerrit changes
            for ci in self.changes_to_fetch:
                project = os.path.basename(ci[0]['project'])
                url = 'changes/%s/revisions/current/submit_type' % (ci[0]['_number'])
                submit_type = self.gerrit_REST_api(url)

                # generate the commands necessary to fetch and merge in (or rebase) this change
                pre_materialize_script_file.write('''\
    #---------------------------------------------------------------------------------------------------------------------------#
    echo -e "\\n=========================================================================================================================================="
    echo -e "*** `date +"%%a %%d/%%b/%%Y %%H:%%M:%%S"` getting Gerrit patch %(GERRIT_REPO)s %(GERRIT_REF)s (branch %(GERRIT_BRANCH)s) ***\\n"
    repo=${materialize_workspace_path}_git/%(GERRIT_REPO)s.git
    if [[ ! -d "${repo}" ]]; then
        mkdir -pv ${materialize_workspace_path}_git
        cd ${materialize_workspace_path}_git
        git clone %(GERRIT_URL)s %(GERRIT_REPO)s.git
    fi
    cd ${repo}

    # check out a local branch with a name that the Buckminster CQuery expects, but possibly based on a differently-named remote
    # this is to handle that case where the expected branch is something like gda-8.44, but the branch we want to test is gda-8.44-i15
    # check out in detached head state, so that we can delete and recreate the local branch
    git checkout origin/%(STANDARD_BRANCH)s
    git branch --force %(STANDARD_BRANCH)s origin/%(GERRIT_BRANCH)s
    git checkout %(STANDARD_BRANCH)s
    git fetch origin %(GERRIT_REF)s
    git show --oneline --no-patch $(git rev-parse FETCH_HEAD)
    git show --oneline --no-patch $(git rev-parse HEAD)

''' %           {'GERRIT_REPO': project,  # something like gda-core (not gda/gda-core)
                 'GERRIT_URL': ci[0]['revisions'].values()[0]['fetch']['ssh']['url'],
                 'GERRIT_REF': ci[0]['revisions'].values()[0]['fetch']['ssh']['ref'],
                 'GERRIT_BRANCH': ci[0]['branch'],
                 'STANDARD_BRANCH': self.get_expected_branch_for_repo(project)
                 })

                if submit_type == 'REBASE_IF_NECESSARY':
                    pre_materialize_script_file.write('''\
    # submit type = REBASE_IF_NECESSARY
    git checkout -f FETCH_HEAD
    git rebase --verbose %(STANDARD_BRANCH)s
'''                     % {'STANDARD_BRANCH': self.get_expected_branch_for_repo(project)})
                else:
                    pre_materialize_script_file.write('''\
    # submit type = %(submit_type)s
    git merge --verbose --no-progress --no-edit --log FETCH_HEAD
'''                     % {'submit_type': submit_type,})

                pre_materialize_script_file.write('''\
    git log %(STANDARD_BRANCH)s^.. --topo-order

'''                 % {'STANDARD_BRANCH': self.get_expected_branch_for_repo(project)})

            #=======================
            # write the pre_materialize function for branch overrides (for repos with no changes in Gerrit)
            # (1) if we have an existing materialization for the repo, we can just switch the HEAD as requested
            # (2) if the repo is in Gerrit, we can ask Gerrit how to clone it, get a clone, and then we can switch the HEAD as requested
            # (3) if the repo is not in Gerrit, we will let Buckminster do the materialize, and switch the HEAD _after_ the materialize
            for (repo, (head, action)) in sorted(self.get_override_branch_for_repo(None).iteritems()):
                # generate the commands necessary to switch the repo to the requested branch

                pre_materialize_script_file.write('''\
    #---------------------------------------------------------------------------------------------------------------------------#
    echo -e "\\n=========================================================================================================================================="
    echo -e "*** `date +"%%a %%d/%%b/%%Y %%H:%%M:%%S"` pre-materialize attempt: switching %(REPO)s to head %(ALTERNATE_HEAD)s using %(ACTION)s ***\\n"
    repo=${materialize_workspace_path}_git/%(REPO)s.git
''' %           {'REPO': os.path.basename(repo),  # something like gda-core (not gda/gda-core)
                 'ALTERNATE_HEAD': head,  # could be a commit as well
                 'ACTION': action,        # merge, checkout
                 })

                clone_url = None
                # find out if it's a Gerrit repository, and get the clone URL
                url = 'projects/?r=.*%s' % (urllib.quote(repo),)  # we need to find the full name for the project, eg gda-core --> gda/gda-core
                projectinfos = self.gerrit_REST_api(url)
                if projectinfos and (len(projectinfos) == 1):
                    # it's a Gerrit repo
                    project = projectinfos.keys()[0]  # there will only be one key (only one matching repo found)
                    project_quoted = urllib.quote_plus(project)
                    # now we need to find out the URL to fetch changes from the repository
                    # get a single commit from the repository (donesn't matter which) and get the fetch URL
                    url = 'changes/?q=project:%s&n=1&o=CURRENT_REVISION' % (project_quoted,)  # get the change record for some arbitrary change; this will give us the fetch URL
                    changeinfo  = self.gerrit_REST_api(url)
                    try:
                        clone_url = changeinfo[0]['revisions'].values()[0]['fetch']['ssh']['url']
                    except Exception as err:
                        self.logger.error('Error getting Gerrit fetch URL: ' % str(err))
                # otherwise, hard-code a few URLs for common checkout cases
                elif repo in ('gda-ispyb-api',):
                    clone_url = 'git://github.com/DiamondLightSource/' + repo + '.git'

                if clone_url:
                    pre_materialize_script_file.write('''\
    if [[ ! -d "${repo}" ]]; then
        mkdir -pv ${materialize_workspace_path}_git
        cd ${materialize_workspace_path}_git
        git clone %(CLONE_URL)s %(REPO)s.git
    fi
''' %           {'REPO': os.path.basename(repo),  # something like gda-core (not gda/gda-core)
                 'CLONE_URL': clone_url,
                 })

# check out a local branch with a name that the Buckminster CQuery expects, but possibly based on a differently-named remote branch or commit
# this is to handle that case where the expected branch is something like gda-8.44, but the branch we want to test is gda-8.44-i15 (or we want to test at an arbitrary commit)
# check out in detached head state, so that we can delete and recreate the local branch
                pre_materialize_script_file.write('''\
    if [[ -d "${repo}" ]]; then
        cd ${repo}
        action=%(ACTION)s
        git checkout origin/%(STANDARD_BRANCH)s
        git fetch origin %(ALTERNATE_HEAD)s
        git show --oneline --no-patch $(git rev-parse FETCH_HEAD)
        git show --oneline --no-patch $(git rev-parse HEAD)

        if [[ "${action}" == "merge" ]]; then
            git merge --verbose --no-progress --no-edit --log FETCH_HEAD
        elif [[ "${action}" == "checkout" ]]; then
            if git branch --list -r | grep /%(ALTERNATE_HEAD)s; then
              # we are switching to a specific branch
              git branch --force %(STANDARD_BRANCH)s origin/%(ALTERNATE_HEAD)s
            else
              # we are switching to a specific commit
              git branch --force %(STANDARD_BRANCH)s %(ALTERNATE_HEAD)s
            fi
            git checkout %(STANDARD_BRANCH)s
            git log %(STANDARD_BRANCH)s^.. --topo-order
            export repo_switched_to_alternate_head_%(REPO_TRANSLATED)s=true
        fi
    else
        export repo_switched_to_alternate_head_%(REPO_TRANSLATED)s=false
        echo "the repo does not exist, so we will allow the materialize to clone it, and afterwards switch the branch"
    fi

''' %           {'REPO_TRANSLATED': os.path.basename(repo).replace('-','_'),  # something like gda_core (not gda/gda-core)
                 'ALTERNATE_HEAD': head,  # could be a commit or a branch
                 'ACTION': action,        # merge or checkout
                 'STANDARD_BRANCH': self.get_expected_branch_for_repo(os.path.basename(repo))
                 })

                if not clone_url:
                    # if not a Gerrit URL, then we might need to switch branches after the materialize
                    with open(POST_MATERIALIZE_FUNCTION_FILE_PATH, 'a') as post_materialize_script_file:
                        post_materialize_script_file.write('''\
    echo -e "\\n=========================================================================================================================================="
    echo -e "*** `date +"%%a %%d/%%b/%%Y %%H:%%M:%%S"` post-materialize attempt: switching %(REPO)s to head %(ALTERNATE_HEAD)s (if not already done in pre-materialize) ***\\n"
    if [[ "${repo_switched_to_alternate_head_%(REPO_TRANSLATED)s}" != "true" ]]; then
        repo=${materialize_workspace_path}_git/%(REPO)s.git
        action=%(ACTION)s
        cd ${repo}
        git checkout origin/%(STANDARD_BRANCH)s
        git branch --force %(STANDARD_BRANCH)s origin/%(STANDARD_BRANCH)s
        git checkout %(STANDARD_BRANCH)s
        git fetch origin %(ALTERNATE_HEAD)s
        git show --oneline --no-patch $(git rev-parse FETCH_HEAD)
        git show --oneline --no-patch $(git rev-parse HEAD)

        if [[ "${action}" == "merge" ]]; then
            git merge --verbose --no-progress --no-edit --log FETCH_HEAD
        elif [[ "${action}" == "checkout" ]]; then
            if git branch --list -r | grep /%(ALTERNATE_HEAD)s; then
              # we are switching to a specific branch
              git branch --force %(STANDARD_BRANCH)s origin/%(ALTERNATE_HEAD)s
            else
              # we are switching to a specific commit
              git branch --force %(STANDARD_BRANCH)s %(ALTERNATE_HEAD)s
            fi
            git checkout %(STANDARD_BRANCH)s
            git log %(STANDARD_BRANCH)s^.. --topo-order
            export repo_switched_to_alternate_head_%(REPO_TRANSLATED)s=true
        fi
        git checkout %(STANDARD_BRANCH)s
        git log %(STANDARD_BRANCH)s^.. --topo-order
    fi

''' %                   {'REPO': os.path.basename(repo),  # something like gda-core (not gda/gda-core)
                         'REPO_TRANSLATED': os.path.basename(repo).replace('-','_'),  # something like gda_core
                         'ALTERNATE_HEAD': head,  # could be a commit or a branch
                         'ACTION': action,        # merge or checkout
                         'STANDARD_BRANCH': self.get_expected_branch_for_repo(os.path.basename(repo))
                        })

            pre_materialize_script_file.write('''\
    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
}

''')
            if self.get_override_branch_for_repo(None):
                # post_materialize_script_file only written if we have non-Gerrit repos in which we are switching branches
                with open(POST_MATERIALIZE_FUNCTION_FILE_PATH, 'a') as post_materialize_script_file:
                    post_materialize_script_file.write('''\
    $([ "$olderrexit" == "0" ]) && set -e || true  # Turn errexit on if it was on at the top of this script
    $([ "$olderrexit" == "1" ]) && set +e || true  # Turn errexit off if it was off at the top of this script
}

''')

    def generate_gerrit_junit_options_command(self):
        ''' generate the environment variable for any extra test options
        '''

        with open(SET_JUNIT_OPTIONS_FILE_PATH, 'w') as junit_options_file:
            junit_options_file.write(self.generated_header)
            for ci in self.changes_to_fetch:
                if ci[0]['project'] == 'eclipse/scanning':
                    junit_options_file.write('# eclipse/scanning included in changes to test, so do NOT skip any tests\n')
                    return
            junit_options_file.write('# eclipse/scanning NOT included in changes to test, so skip tests in it\n')
            junit_options_file.write('junit_tests_skip_scanning=\'--exclude=org.eclipse.scanning.*\'\n')

    def generate_gerrit_ssh_command(self):
        ''' generate the first part of the ssh commands to post the verified status for the changes we tested
            note that we don't just post the result for the changes that we fetched, but possibly for earlier changes in the chain too
        '''

        self.ssh_fetched_changes = []  # list of [ssh command, text describing additional changes implicitly included] for the change we fetched for each repo
        self.ssh_ancestor_changes = []  # list of ssh commands for unmerged older commits that were implicitly tested
        for ci in self.changes_to_fetch:
            self.ssh_fetched_changes.append(
                ['%s gerrit review %s,%s -p %s -n NONE' % (self.gerrit_ssh_command, ci[0]['_number'], ci[0]['revisions'].values()[0]['_number'], ci[0]['project']),
                 '']
                )
            if len(ci) > 1:  # if the fetched change includes older unmerged changes in its dependency chain
                self.ssh_fetched_changes[-1][-1] = (' (includes older change' + ('','s')[bool(len(ci)>2)] + ' ' +
                                              str([str('%s/%s' % (cr['_change_number'], cr['_revision_number'])) for cr in ci[1:]]).translate(None,b"'[]") + ')')
                for cr in ci[1:]:
                    self.ssh_ancestor_changes.append(
                        ['%s gerrit review %s,%s -n NONE' % (self.gerrit_ssh_command, cr['_change_number'], cr['_revision_number']),  # project not in record
                         ' (tested as part of newer change ' + str(ci[0]['_number']) + '/' + str(ci[0]['revisions'].values()[0]['_number']) + ')']
                        )

    def write_gerrit_at_start_function(self):
        ''' write the function to post Gerrit that the verification job has started
        '''

        if not self.changes_to_test:
            return  # no changes requested

        with open(NOTIFY_GERRIT_AT_START_FUNCTION_FILE_PATH, 'w') as started_script_file:
            started_script_file.write(self.generated_header)
            started_script_file.write('\npre_materialize_function_stage1_gerrit_job_started () {\n')
            started_script_file.write('  # this function is invoked at the start of the testing\n')
            started_script_file.write('  # post a status message back to each Gerrit change to be tested\n\n')
            if "don't post anything" in self.gerrit_verified_option:
                started_script_file.write('  return  # job parameters specified not to post to Gerrit\n\n')

            started_script_file.write('  set -x  # Turn on xtrace\n')
            started_script_file.write('  # clear any existing verified status\n')
            for c in self.ssh_fetched_changes:
                started_script_file.write('  %s --message \'"Build Started%s %s"\''
                                  % (c[0], c[1],  os.environ.get('BUILD_URL','')))
                if "status unchanged" not in self.gerrit_verified_option:
                    started_script_file.write(' --verified 0')
                started_script_file.write(' || true\n')
            if self.ssh_ancestor_changes:  # if the change had older unmerged related changes
                if not self.gerrit_verify_ancestors:
                    started_script_file.write('  set +x  # Turn off xtrace\n')
                    started_script_file.write('  return  # job parameter gerrit_verify_ancestors specified not to verify older unmerged changes that are included\n\n')
                else:
                    started_script_file.write('\n  # job parameter gerrit_verify_ancestors specified to also verify older unmerged changes that are included\n')
                for c in self.ssh_ancestor_changes:
                    started_script_file.write('  %s --message \'"Build Started%s %s"\' || true\n'
                                      % (c[0], c[1],  os.environ.get('BUILD_URL','')))
            started_script_file.write('  set +x  # Turn off xtrace\n')
            started_script_file.write('}\n\n')

    def write_gerrit_at_end_functions(self):
        ''' write the functions to post Gerrit that the verification job has finished, along with the result
            note that we don't just post the result for the changes that we fetched, but possibly for earlier changes in the chain too
        '''

        if not self.changes_to_test:
            return  # no changes requested

        with open(NOTIFY_GERRIT_AT_END_FUNCTION_FILE_PATH, 'w') as finished_script_file:
            finished_script_file.write(self.generated_header)

            # the script that is run if the test job passed
            finished_script_file.write('\nnotify_gerrit_job_passed () {\n')
            finished_script_file.write('  # this function is invoked at the end of successful testing\n')
            finished_script_file.write('  # post a status message back to each Gerrit change tested\n\n')
            if "don't post anything" in self.gerrit_verified_option:
                finished_script_file.write('  return  # job parameters specified not to post to Gerrit\n\n')

            finished_script_file.write('  set -x  # Turn on xtrace\n')
            finished_script_file.write('  # set the verified status to +1\n')
            for c in self.ssh_fetched_changes:
                finished_script_file.write('  %s --message \'"Build Successful%s %s"\''
                                  % (c[0], c[1],  os.environ.get('BUILD_URL','')))
                if "+1" in self.gerrit_verified_option:
                    finished_script_file.write(' --verified +1')
                finished_script_file.write(' || true\n')
            if self.ssh_ancestor_changes:  # if the change had older unmerged related changes
                if not self.gerrit_verify_ancestors:
                    finished_script_file.write('  set +x  # Turn off xtrace\n')
                    finished_script_file.write('  return  # job parameter gerrit_verify_ancestors specified not to verify older unmerged changes that were included\n\n')
                else:
                    finished_script_file.write('\n  # job parameter gerrit_verify_ancestors specified to also verify older unmerged changes that were included\n')
                for c in self.ssh_ancestor_changes:
                    finished_script_file.write('  %s --message \'"Build Successful%s %s"\''
                                      % (c[0], c[1],  os.environ.get('BUILD_URL','')))
                    if "+1" in self.gerrit_verified_option:
                        finished_script_file.write(' --verified +1')
                    finished_script_file.write(' || true\n')
            finished_script_file.write('  set +x  # Turn off xtrace\n')
            finished_script_file.write('}\n')

            # the script that is run if the test job failed
            finished_script_file.write('\nnotify_gerrit_job_failed () {\n')
            finished_script_file.write('  # this function is invoked at the end of unsuccessful testing\n')
            finished_script_file.write('  # post a status message back to each Gerrit change tested\n\n')
            if "don't post anything" in self.gerrit_verified_option:
                finished_script_file.write('  return  # job parameters specified not to post to Gerrit\n\n')

            finished_script_file.write('  set -x  # Turn on xtrace\n')
            for c in self.ssh_fetched_changes:
                finished_script_file.write('  %s --message \'"Build Failed%s %s"\''
                                  % (c[0], c[1],  os.environ.get('BUILD_URL','')))
                if "-1" in self.gerrit_verified_option:
                    finished_script_file.write(' --verified -1')
                finished_script_file.write(' || true\n')
            finished_script_file.write('  set +x  # Turn off xtrace\n')
            # don't change verified status of ancestor jobs
            finished_script_file.write('}\n\n')

    def process_requested_changes(self):
        self.get_expected_branch_for_repo(None)  # initial setup
        self.get_override_branch_for_repo(None)  # initial setup
        self.get_changes_from_gerrit()
        return_code = self.process_changes_from_gerrit()
        self.jenkins_build_description = self.jenkins_build_description.strip()
        if self.jenkins_build_description:
            if self.jenkins_build_description.endswith('<br>'):
                self.jenkins_build_description = self.jenkins_build_description[:-4].strip()
            if self.jenkins_build_description:
                # print text that will be read by SetBuildDescriptionBuildstep.groovy
                jbd = 'append-build-description: ' + self.jenkins_build_description.strip()
                if (sys.stdout.encoding is None) and (sys.getdefaultencoding() == 'ascii') and os.environ.get('LANG').upper().endswith('UTF-8'):
                    # When running under Jenkins, Python does not correctly determine the console encoding, so force
                    # it to UTF-8 so any non-Ascii characters in the commit message don't raise a UnicodeEncodeError
                    print(jbd.encode('utf-8'))
                else:
                    print(jbd)
        if return_code:
            return return_code  # error in changes requested
        if not (self.changes_to_test or self.get_override_branch_for_repo(None)):
            return 0  # no changes requested
        self.write_pre_post_materialize_functions()
        self.generate_gerrit_junit_options_command()
        self.generate_gerrit_ssh_command()
        self.write_gerrit_at_start_function()
        self.write_gerrit_at_end_functions()
        return 0

if __name__ == '__main__':

    return_code = RequestedChangesProcessor().process_requested_changes()
    sys.exit(return_code)

