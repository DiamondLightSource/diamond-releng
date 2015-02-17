'''
Given one or more Gerrit changeset numbers, generates a script to apply them, one on top of another, to a set of repositories 
'''

from __future__ import print_function
import itertools
import json
import operator
import os
import urllib2
import sys

MAX_CHANGESETS = 5  # the number of parameters in the Jenkins job 

SCRIPT_FILE_PATH = os.path.abspath(os.path.expanduser(os.path.join(os.environ['WORKSPACE'], 'gerrit.multiple_pre.post.materialize.functions.sh')))

def write_script_file_start():
    with open(SCRIPT_FILE_PATH, 'w') as script_file:
                script_file.write('''\

. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/pre.materialize_checkout.standard.branches_function.sh

pre_materialize_function_stage2_gerrit_multiple () {

''')

def write_script_file_end():
    
    with open(SCRIPT_FILE_PATH, 'a') as script_file:
                script_file.write('''\
}

''')

def write_script_file_for_changes():
    ''' validate the environment variables passed by Jenkins '''

    changes_to_fetch = []  # list of (project, change, current_revision_number, change_id, refspec)
    errors_found = False

    for i, change in ((i, os.environ.get('change_%s' % i, '').strip()) for i in range(1, MAX_CHANGESETS+1)):
        if not change:
            continue
        # check that the change is numeric
        try:
            assert str(int(change)) == change
        except (ValueError, AssertionError):
            print('*** Error: invalid change_%s: "%s"' % (i, change))
            errors_found = True
            continue
        else:
            change = int(change)

        # use the Gerrit REST interface to get some details about the change (do some basic validation on what is returned)
        url = 'http://gerrit.diamond.ac.uk:8080/changes/?q=%s&o=CURRENT_REVISION' % (change,)
        request = urllib2.Request(url)
        try:
            changeinfo_json = urllib2.urlopen(request).read()
        except (urllib2.HTTPError) as err:
            print('*** Error: invalid response from Gerrit server reading %s: %s' % (url, err))
            errors_found = True
            continue
        if not changeinfo_json.startswith(")]}'\n"):
            print('*** Error: invalid response from Gerrit server reading %s: magic prefix line not found' % (url,))
            errors_found = True
            continue
        changeinfo = json.loads(changeinfo_json[5:])  # need to strip off the magic prefix line returned by Gerrit

        # check that this change is for the correct branch, and has not already been merged
        project = str(changeinfo[0]['project'])  # str converts from unicode 
        change_branch = changeinfo[0].get('branch', '**not returned by Gerrit**')
        expected_branch = os.environ.get('repo_default_BRANCH', '**not set in Jenkins environment**')
        status = str(changeinfo[0]['status'])
        if change_branch != expected_branch:
            print('*** Error: change %s branch ("%s") does not match the branch used by this test job ("%s")' % (change, change_branch, expected_branch))
            errors_found = True
            continue
        if status not in ('NEW', 'DRAFT'):
            print('*** Error: change %s is not eligible for testing: status is %s' % (change, status))
            errors_found = True
            continue
        change_id = changeinfo[0]['change_id']
        current_revision = changeinfo[0]['current_revision']
        current_revision_number = changeinfo[0]['revisions'][current_revision]['_number']
        refspec = changeinfo[0]['revisions'][current_revision]['fetch']['anonymous http']['ref']
        changes_to_fetch.append((project, change, current_revision_number, change_id, refspec))

        if errors_found:
            sys.exit(1)

    # sort the changes to apply in order of project, and change ascending, and group changes in the same project
    changes_to_fetch.sort(key=operator.itemgetter(1))  # sort on secondary key, the change (a number)
    changes_to_fetch.sort()  # sort on primary key, the project (repository), taking advantage of the fact that sorts are stable

    for (project, change, current_revision_number, change_id, refspec) in changes_to_fetch:
        print((project, change, current_revision_number, change_id, refspec))

        # generate the commands necessary to fetch and merge in this change
        with open(SCRIPT_FILE_PATH, 'a') as script_file:
            script_file.write('''\
    GERRIT_PROJECT=%(GERRIT_PROJECT)s
    GERRIT_REFSPEC=%(GERRIT_REFSPEC)s
    echo -e "\\n*** `date +"%%a %%d/%%b/%%Y %%H:%%M:%%S"` getting Gerrit patch ${GERRIT_PROJECT} ${GERRIT_REFSPEC} (branch ${repo_default_BRANCH}) ***\\n"
    repo=${materialize_workspace_path}_git/$(basename ${GERRIT_PROJECT}).git
    if [[ ! -d "${repo}" ]]; then
        mkdir -pv ${materialize_workspace_path}_git
        cd ${materialize_workspace_path}_git
        git clone ${GERRIT_SCHEME}://${GERRIT_HOST}:${GERRIT_PORT}/${GERRIT_PROJECT} ${repo}
    fi

    # do the merge or rebase in a new local branch, to avoid any risk of pushing something back to the remote
    cd ${repo}
    git checkout ${repo_default_BRANCH}
    git branch -D local-${JOB_NAME} || true
    git branch -vv --no-track local-${JOB_NAME} remotes/origin/${repo_default_BRANCH}
    git checkout local-${JOB_NAME}
    git fetch origin ${GERRIT_REFSPEC}

    # Merge or rebase the change on the (local version of the) main branch, using whatever method is specified for Gerrit's "Submit Type:" for the repository
    submit_type=$(wget -q -O - "http://${GERRIT_HOST}:8080/projects/$(echo ${GERRIT_PROJECT} | sed 's#/#%%2F#g')/config" | grep '"submit_type"')
    if [[ "${submit_type}" == *REBASE_IF_NECESSARY* ]]; then
        # option - attempt to rebase the change with the main branch
        git checkout -f FETCH_HEAD
        git rebase --verbose local-${JOB_NAME}
    else
        # option - attempt to merge the change with the (local version of the) main branch
        git merge --verbose FETCH_HEAD
    fi

    git log master^..

''' % {'GERRIT_PROJECT': project, 'GERRIT_REFSPEC': refspec,}

)

if __name__ == '__main__':
    write_script_file_start()
    write_script_file_for_changes()
    write_script_file_end()

