###
### Generate a bash script to tag repositories at a specified point
### Assumes that the current directory is the Jenkins workspace
###

from __future__ import print_function

import os
import re
import sys
import time

def generate_make_branch_tag_script():

    REPOSITORIES_TO_IGNORE = ()

    # set up environment
    if not len(sys.argv) == 2:
        print('*** ERROR: exactly one parameter is required: the absolute path to a work directory (which must not already exist)')
        sys.exit(1)
    work_dir = os.path.expanduser(sys.argv[1])
    if not os.path.isabs(work_dir):
        print('*** ERROR: parameter must be an absolute path, but is "%s"' % (work_dir,))
        sys.exit(1)
    if os.path.exists(work_dir):
        print('*** ERROR: parameter must specify a directory that does not exist, but "%s" exists' % (work_dir,))
        sys.exit(1)

    ###############################################################################
    #  Constants for the bash script to set up the repositories                    #
    ###############################################################################

    BASH_PREAMBLE = \
'''###

set -o errexit
set -o nounset
set -o xtrace

work_dir=%(work_dir)s

rm -rf ${work_dir}
mkdir -pv ${work_dir}

#------------------------------------#''' % {'work_dir': work_dir}

    BASH_GIT_PREAMBLE = \
'''
echo -e "\\n**** Processing %(repository)s ****\\n"
date +"%%a %%d/%%b/%%Y %%H:%%M:%%S"
cd ${work_dir}
git clone %(URL)s %(repository)s
cd %(repository)s
git branch -a'''

    BASH_GIT_TAG = \
'''# make tag at specified commit
git checkout master
git tag -a -m "%(tag_commitmsg)s" %(tag_name_preamble)s%(tag_name)s %(HEAD)s
git push --verbose --tags'''

    BASH_GIT_BRANCH = \
'''# make branch at specified commit
git checkout master
git checkout -b %(branch_name_preamble)s%(branch_name)s %(HEAD)s
git status
git push --verbose -u origin %(branch_name_preamble)s%(branch_name)s
git branch -a'''

    tag_name = os.environ.get('tag_name')
    tag_commitmsg = os.environ.get('tag_commitmsg')
    branch_name = os.environ.get('branch_name')

    tag_name_preamble = os.environ.get('tag_name_preamble','')
    tag_name_preamble_repos = os.environ.get('tag_name_preamble_repos')
    branch_name_preamble = os.environ.get('branch_name_preamble','')
    branch_name_preamble_repos = os.environ.get('branch_name_preamble_repos')

    github_anonymous_prefix = 'git://github.com/'
    github_authenticated_prefix = 'git@github.com:'

    # generate the bash script to branch the Git repositories
    print('### File generated on %s\n###' % (time.strftime("%a, %Y/%m/%d %H:%M:%S"),))
    if tag_name and tag_commitmsg:
        print('### make tags in Git repositories')
        for name in (
        'tag_name',
        'tag_commitmsg',
        'tag_name_preamble',
        'tag_name_preamble_repos',
        ):
            print("### %-26s = %s" % (name, locals()[name]))
    if branch_name:
        print('### make branches in Git repositories')
        for name in (
        'branch_name',
        'branch_name_preamble',
        'branch_name_preamble_repos',
        ):
            print("### %-26s = %s" % (name, locals()[name]))
    print(BASH_PREAMBLE)

    if tag_name_preamble_repos:
        tag_name_preamble_repos = re.compile(tag_name_preamble_repos)
    if branch_name_preamble_repos:
        branch_name_preamble_repos = re.compile(branch_name_preamble_repos)

    with open('artifacts_to_archive/head_commits.txt', 'r') as commits_file:
        for line in commits_file:  # standard OS terminator is converted to \n
            line = line.rstrip('\n') # remove trailing newline
            if line.startswith('#') or (not line.strip()):
                continue
            repo_to_action = {}
            # note that BRANCH is the checked-out branch in the original build job (usually master), _not_ the new branch we are making
            # a commit can of course be on more than one branch
            for token in ('repository', 'URL', 'HEAD', 'BRANCH'):
                try:
                    i = line.index(token + '=')
                    j = line.index('***', i+len(token)+1)
                except ValueError:
                    if token == 'BRANCH':
                        # we don't actually use BRANCH here, and older versions of record_head_commits_function.sh did not write it, so it's ok it it's missing
                        continue
                    print('*** ERROR looking for token "%s" in string "%s"' % (token, line))
                    raise
                repo_to_action[token] = line[i+len(token)+1:j]
            if repo_to_action['repository'] in REPOSITORIES_TO_IGNORE:
                print('\n# skipping %(repository)s, since it is in the ignore list' % {'repository': repo_to_action['repository']})
                continue
            if repo_to_action['URL'].startswith(github_anonymous_prefix):
                repo_to_action['URL'] = github_authenticated_prefix + repo_to_action['URL'][len(github_anonymous_prefix):]  # convert URL from anonymous clone to authenticated
            print(BASH_GIT_PREAMBLE % {'repository': repo_to_action['repository'], 'URL': repo_to_action['URL']})
            if tag_name and tag_commitmsg:
                preamble = tag_name_preamble if tag_name_preamble and tag_name_preamble_repos and tag_name_preamble_repos.match(repo_to_action['repository']) else ''
                print(BASH_GIT_TAG % {'tag_name_preamble': preamble, 'tag_name': tag_name, 'tag_commitmsg': tag_commitmsg, 'HEAD': repo_to_action['HEAD']})
            if branch_name:
                preamble = branch_name_preamble if branch_name_preamble and branch_name_preamble_repos and branch_name_preamble_repos.match(repo_to_action['repository']) else ''
                print(BASH_GIT_BRANCH % {'branch_name_preamble': preamble, 'branch_name': branch_name, 'HEAD': repo_to_action['HEAD']})
        print('\ncd ${work_dir}/..\n')

###############################################################################
# Command line processing                                                     #
###############################################################################

if __name__ == '__main__':
    generate_make_branch_tag_script()
