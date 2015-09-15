'''
Given multiple Gerrit changesets, generates a script to apply them, one on top of another, to a set of repositories.
The changesets to be tested together can be specified either by a single Gerrit "topic", or by a set of changeset numbers (or both, though that is not good practice).

Testing notes:
   Set environment variables something like this:
      export WORKSPACE=
      export topic_1=GDA-1234
      export change_1=664
      export repo_default_BRANCH=gda-8.46
'''

from __future__ import absolute_import, division, print_function

import itertools
import json
import operator
import os
import os.path
import stat
import sys
import time
import urllib
import urllib2

MAX_TOPICS = 5  # a number >= the number of parameters in the Jenkins job
MAX_CHANGESETS = 20  # a number >= the number of parameters in the Jenkins job

CHANGE_LIST_FILE_PATH = os.path.abspath(os.path.expanduser(os.path.join(os.environ['WORKSPACE'], 'artifacts_to_archive', 'gerrit_changes_tested.txt')))
PRE_MATERIALIZE_FUNCTION_FILE_PATH = os.path.abspath(os.path.expanduser(os.path.join(os.environ['WORKSPACE'], 'artifacts_to_archive', 'gerrit.manual_pre.post.materialize.functions.sh')))

# If the Gerrrit REST API has been secured, then you need to use digest authentication.
USE_DIGEST_AUTHENTICATION = os.environ.get('GERRIT_USE_DIGEST_AUTHENTICATION', 'true').strip().lower() != 'false'

def get_http_username_password():
    ''' the token required to authenticate to Gerrit is stored in a file '''
    assert USE_DIGEST_AUTHENTICATION, "*** Internal Error: get_http_username_password called, but USE_DIGEST_AUTHENTICATION False"
    token_filename = os.path.abspath(os.path.expanduser('~/passwords/http-password_Gerrit_for-REST.txt'))
    assert os.path.isfile(token_filename)
    assert os.stat(token_filename).st_mode == stat.S_IRUSR + stat.S_IFREG  # permissions must be user-read + regular-file
    last_nonempty_line = ''
    with open(token_filename, 'r') as token_file:
        for line in token_file:  # standard OS terminator is converted to \n
            line = line.rstrip('\n') # remove trailing newline
            if line:
                last_nonempty_line = line
    if last_nonempty_line:
        return last_nonempty_line.split(':', 1)
    raise Exception('File %s appears empty' % token_filename)

def parse_changeinfo(changeinfo, change_list_file):
    '''
    A Gerrit ChangeInfo entity contains information about a change
    This function parses a changeinfo, and either
        returns a tuple of extracted data, or
        None, if the change is not applicable in the current context
    '''
    # check that this change is for the correct branch, and has not already been merged
    change = str(changeinfo['_number'])  # str converts from unicode
    project = str(changeinfo['project'])  # str converts from unicode
    change_branch = changeinfo.get('branch', '**not returned by Gerrit**')
    repo_branch_env_var = 'repo_%s_BRANCH' % (os.path.basename(project).replace('.git', '').replace('-', '_'),)
    expected_branch = os.environ.get(repo_branch_env_var, os.environ.get('repo_default_BRANCH', '**not set in Jenkins environment**'))
    status = str(changeinfo['status'])
    if change_branch != expected_branch:
        change_list_file.write('# Error: change %s branch ("%s") in %s does not match the branch used by this test job ("%s")\n' %
                               (change, change_branch, project, expected_branch))
        return None
    if status not in ('NEW', 'DRAFT'):
        change_list_file.write('# Error: change %s is not eligible for testing: status is %s\n' % (change, status))
        return None
    change_id = changeinfo['change_id']
    current_revision = changeinfo['current_revision']
    current_revision_number = changeinfo['revisions'][current_revision]['_number']
    if USE_DIGEST_AUTHENTICATION:
        refspec = changeinfo['revisions'][current_revision]['fetch']['http']['ref']
    else:
        refspec = changeinfo['revisions'][current_revision]['fetch']['anonymous http']['ref']
    return (project, change, current_revision_number, change_id, refspec)


def write_script_file():

    if USE_DIGEST_AUTHENTICATION:
        handler = urllib2.HTTPDigestAuthHandler()
        handler.add_password('Gerrit Code Review', 'http://gerrit.diamond.ac.uk:8080', *get_http_username_password())
        opener = urllib2.build_opener(handler)
        urllib2.install_opener(opener)

    urls_to_query = []  # list of Gerrit URLs to query to get change information
    errors_found = 0

    with open(CHANGE_LIST_FILE_PATH, 'a') as change_list_file:
        # Build the query URL for each topic specified
        for i, topic in ((i, os.environ.get('topic_%s' % i, '').strip()) for i in range(1, MAX_TOPICS+1)):
            if not topic:
                continue
            url = 'http://gerrit.diamond.ac.uk:8080/'
            if USE_DIGEST_AUTHENTICATION:
                url += 'a/'
            url += 'changes/?q=topic:{%s}&o=CURRENT_REVISION' % (urllib.quote(topic,''),)
            urls_to_query.append(url)
            change_list_file.write('# build parameters specified testing of topic = %s\n' % (topic,))

        # Build the query URL for each change number specified
        for i, change in ((i, os.environ.get('change_%s' % i, '').strip()) for i in range(1, MAX_CHANGESETS+1)):
            if not change:
                continue
            try:
                assert str(int(change)) == change  # check that the change is numeric
            except (ValueError, AssertionError):
                change_list_file.write('# Error: invalid change_%s: "%s"\n' % (i, change))
                errors_found = True
                continue
            else:
                change = int(change)
            url = 'http://gerrit.diamond.ac.uk:8080/'
            if USE_DIGEST_AUTHENTICATION:
                url += 'a/'
            url += 'changes/?q=change:%s&o=CURRENT_REVISION' % (change,)
            urls_to_query.append(url)
            change_list_file.write('# build parameters specified testing of change = %s\n' % (change,))

        changes_to_fetch = []
        for url in urls_to_query:
            request = urllib2.Request(url)
            try:
                changeinfo_json = urllib2.urlopen(request).read()
            except (urllib2.HTTPError) as err:
                change_list_file.write('# Error: invalid response from Gerrit server reading %s: %s\n' % (url, err))
                errors_found = True
                continue
            if not changeinfo_json.startswith(")]}'\n"):
                change_list_file.write('# Error: invalid response from Gerrit server reading %s: magic prefix line not found\n' % (url,))
                errors_found = True
                continue
            changeinfo = json.loads(changeinfo_json[5:])  # need to strip off the magic prefix line returned by Gerrit
            if len(changeinfo) == 0:
                change_list_file.write('# Error: item %s does not exist (or is not visible to Jenkins)\n' % (url.partition('?')[2].partition('&')[0],))
                errors_found = True
                continue
            change_list_file.write('# Info: querying item %s\n' % (url.partition('?')[2].partition('&')[0],))
            for ci in changeinfo:
                extracted_changeinfo = parse_changeinfo(ci, change_list_file)
                if not extracted_changeinfo:
                    errors_found = True
                    continue
                changes_to_fetch.append(extracted_changeinfo)

        if errors_found:
            if changes_to_fetch:
                change_list_file.write('# Info: remaining changes specified that are eligible for testing: ' + 
                      str(['%s/%s' % (change, current_revision_number) for (project, change, current_revision_number, change_id, refspec) in changes_to_fetch]) +
                      '\n')
            return 1
        if not changes_to_fetch:
            change_list_file.write('# Error: no changes specified (you need to set the appropriate environment variables)\n')
            return 1

    # check that we didn't get any duplicated change numbers
    change_numbers = [change for (project, change, current_revision_number, change_id, refspec) in changes_to_fetch]
    distinct_change_numbers = set(change_numbers)
    if len(change_numbers) != len(distinct_change_numbers):
        change_list_file.write('# Error: the following change numbers were specified more than once: ' + 
                               str(sorted([c for c in distinct_change_numbers if change_numbers.count(c) > 1])) +
                               '\n')
        return 1

    # sort the changes to apply in order of project, and change ascending, and group changes in the same project
    changes_to_fetch.sort(key=operator.itemgetter(1))  # sort on secondary key, the change (a number)
    changes_to_fetch.sort()  # sort on primary key, the project (repository), taking advantage of the fact that sorts are stable

    # append to the change list file (a record of what changes we are testing)
    # write the pre_materialize stage1 function into the script file
    gerrit_verified_option = os.environ.get('gerrit_verified_option', '')

    with open(CHANGE_LIST_FILE_PATH, 'a') as change_list_file:
      with open(PRE_MATERIALIZE_FUNCTION_FILE_PATH, 'a') as script_file:
        script_file.write(generated_header)
        script_file.write('\n. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.materialize_checkout.standard.branches_function.sh\n\n')
        if "don't post anything" not in gerrit_verified_option:
            script_file.write('pre_materialize_function_stage1_gerrit_manual () {\n')

        for (project, change, current_revision_number, change_id, refspec) in changes_to_fetch:
            repo_branch_env_var = 'repo_%s_BRANCH' % (os.path.basename(project).replace('.git', '').replace('-', '_'),)
            repo_branch = os.environ.get(repo_branch_env_var, os.environ.get('repo_default_BRANCH', '**not set in Jenkins environment**'))

            change_list_file.write('%s***%s***%s***%s***%s***%s***\n' % (project, change, current_revision_number, change_id, refspec, repo_branch))
            review_command_message = '--message \'"Build Started ' + os.environ.get('BUILD_URL','') + '"\''
            if "don't post anything" not in gerrit_verified_option:
                script_file.write('    ssh -p ${GERRIT_PORT} ${GERRIT_HOST} gerrit review %s,%s -p %s -n NONE %s | true\n'
                                  % (change, current_revision_number, project, review_command_message))
        if "don't post anything" not in gerrit_verified_option:
            script_file.write('}\n\n')

    # write the pre_materialize stage1 function into the script file
    with open(PRE_MATERIALIZE_FUNCTION_FILE_PATH, 'a') as script_file:
        script_file.write('pre_materialize_function_stage2_gerrit_manual () {\n\n')

        for (project, change, current_revision_number, change_id, refspec) in changes_to_fetch:
            repo_branch_env_var = 'repo_%s_BRANCH' % (os.path.basename(project).replace('.git', '').replace('-', '_'),)
            repo_branch = os.environ.get(repo_branch_env_var, os.environ.get('repo_default_BRANCH', '**not set in Jenkins environment**'))

            # generate the commands necessary to fetch and merge in this change
            script_file.write('''\
    GERRIT_PROJECT=%(GERRIT_PROJECT)s
    GERRIT_REFSPEC=%(GERRIT_REFSPEC)s
    echo -e "\\n*** `date +"%%a %%d/%%b/%%Y %%H:%%M:%%S"` getting Gerrit patch ${GERRIT_PROJECT} ${GERRIT_REFSPEC} (branch %(repo_branch)s) ***\\n"
    repo=${materialize_workspace_path}_git/$(basename ${GERRIT_PROJECT}).git
    if [[ ! -d "${repo}" ]]; then
        mkdir -pv ${materialize_workspace_path}_git
        cd ${materialize_workspace_path}_git
        git clone ${GERRIT_SCHEME}://${GERRIT_HOST}:${GERRIT_PORT}/${GERRIT_PROJECT} ${repo}
    fi

    # do the merge or rebase in a new local branch, to avoid any risk of pushing something back to the remote
    cd ${repo}
    git checkout %(repo_branch)s
    git branch -D local-${JOB_NAME} || true
    git branch -vv --no-track local-${JOB_NAME} remotes/origin/%(repo_branch)s
    git checkout local-${JOB_NAME}
    git fetch origin ${GERRIT_REFSPEC}

    # Merge or rebase the change on the (local version of the) main branch, using whatever method is specified for Gerrit's "Submit Type:" for the repository
''' % {'GERRIT_PROJECT': project, 'GERRIT_REFSPEC': refspec, 'repo_branch': repo_branch})

            if USE_DIGEST_AUTHENTICATION:
                script_file.write('''\
    submit_type=$(curl --silent --fail --digest -K ~/passwords/http-password_Gerrit_for-curl.txt "http://${GERRIT_HOST}:8080/a/projects/$(echo ${GERRIT_PROJECT} | sed 's#/#%2F#g')/config" | grep '"submit_type"')
''')
            else:
                script_file.write('''\
    submit_type=$(curl --silent --fail "http://${GERRIT_HOST}:8080/projects/$(echo ${GERRIT_PROJECT} | sed 's#/#%2F#g')/config" | grep '"submit_type"')
''')

            script_file.write('''\

    if [[ "${submit_type}" == *REBASE_IF_NECESSARY* ]]; then
        # option - attempt to rebase the change with the main branch
        git checkout -f FETCH_HEAD
        git show --oneline --no-patch $(git rev-parse FETCH_HEAD)
        git show --oneline --no-patch $(git rev-parse HEAD)
        git rebase --verbose local-${JOB_NAME}
    else
        # option - attempt to merge the change with the (local version of the) main branch
        git show --oneline --no-patch $(git rev-parse FETCH_HEAD)
        git show --oneline --no-patch $(git rev-parse HEAD)
        git merge --verbose FETCH_HEAD
    fi

    git log %(repo_branch)s^.. --topo-order

''' % {'repo_branch': repo_branch})

        script_file.write('''\
}

''')

if __name__ == '__main__':

    # header line for files that we write
    generated_header = ('### File generated ' + time.strftime("%a, %Y/%m/%d %H:%M:%S UTC%z") +
                        ' (' + os.environ.get('BUILD_TAG','$BUILD_TAG:missing') + ' ' + os.environ.get('BUILD_URL','$BUILD_URL:missing') + ')\n')
    with open(CHANGE_LIST_FILE_PATH, 'w') as change_list_file:
        change_list_file.write(generated_header)
    with open(PRE_MATERIALIZE_FUNCTION_FILE_PATH, 'w') as script_file:
        script_file.write(generated_header)

    return_code = write_script_file()
    print('Done: wrote report file to', CHANGE_LIST_FILE_PATH)
    print('Done: wrote script file to', PRE_MATERIALIZE_FUNCTION_FILE_PATH)

    sys.exit(return_code)

