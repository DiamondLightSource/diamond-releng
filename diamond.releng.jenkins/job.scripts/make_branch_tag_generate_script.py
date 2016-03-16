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

    REPOSITORIES_TO_ALWAYS_IGNORE = ()  # tuple of repositories to always ignore

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
git checkout %(BRANCH)s
git tag -a -m "%(tag_commitmsg)s" %(tag_name)s %(HEAD)s
git push --verbose --tags'''

    BASH_GIT_BRANCH = \
'''# make branch at specified commit
git checkout %(BRANCH)s
git checkout -b %(branch_name)s %(HEAD)s
git status
git push --verbose -u origin %(branch_name)s
git branch -a'''

    tag_name = os.environ.get('tag_name')
    tag_commitmsg = os.environ.get('tag_commitmsg')
    branch_name = os.environ.get('branch_name')

    repository_names_to_include_pattern = os.environ.get('repository_names_to_include_pattern','')
    repository_names_to_exclude_pattern = os.environ.get('repository_names_to_exclude_pattern','')

    github_anonymous_prefix = 'git://github.com/'
    github_authenticated_prefix = 'git@github.com:'

    # generate the bash script to branch the Git repositories
    print('### File generated ' + time.strftime("%a, %Y/%m/%d %H:%M:%S %z") +
          ' (' + os.environ.get('BUILD_URL','$BUILD_URL:missing') + ')\n###')
    for name in (
    'repository_names_to_include_pattern',
    'repository_names_to_exclude_pattern',
    ):
        print("### %-35s = %s" % (name, locals()[name]))
    if tag_name and tag_commitmsg:
        print('###\n### make tags in Git repositories')
        for name in (
        'tag_name',
        'tag_commitmsg',
        ):
            print("### %-35s = %s" % (name, locals()[name]))
    if branch_name:
        print('###\n### make branches in Git repositories')
        for name in (
        'branch_name',
        ):
            print("### %-35s = %s" % (name, locals()[name]))
    print(BASH_PREAMBLE)

    repository_names_to_include_compiled = re.compile(repository_names_to_include_pattern) if repository_names_to_include_pattern else ''
    repository_names_to_exclude_compiled = re.compile(repository_names_to_exclude_pattern) if repository_names_to_exclude_pattern else ''

    repos_to_action = {}
    head_commits_filename = 'artifacts_to_archive/materialized_head_commits.txt'
    if not os.path.isfile(head_commits_filename):
        print('*** ERROR: could not find file with materialized head commits')
        sys.exit(1)
    with open(head_commits_filename, 'r') as commits_file:
        for line in commits_file:  # standard OS terminator is converted to \n
            line = line.rstrip('\n') # remove trailing newline
            if line.startswith('#') or (not line.strip()):
                continue
            # note that BRANCH is the checked-out branch in the original build job (usually master), _not_ the new branch we are making
            # a commit can of course be on more than one branch
            repo_name = None
            repo_description = {}
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
                if token == 'repository':
                    repo_name = line[i+len(token)+1:j]
                else:
                    repo_description[token] = line[i+len(token)+1:j]
            repos_to_action[repo_name] = repo_description

    skip_count = 0
    for repo_name in sorted(repos_to_action):
        if repo_name in REPOSITORIES_TO_ALWAYS_IGNORE:
            print('# skipping %(repository)-35s since it is in the global ignore list' % {'repository': repo_name})
            skip_count += 1
            del repos_to_action[repo_name]
            continue
        if repository_names_to_include_compiled and not repository_names_to_include_compiled.match(repo_name):
            print('# skipping %(repository)-35s since it does not match the include pattern: %(pattern)s' % {'repository': repo_name, 'pattern': repository_names_to_include_pattern})
            del repos_to_action[repo_name]
            skip_count += 1
            continue
        if repository_names_to_exclude_compiled and repository_names_to_exclude_compiled.match(repo_name):
            print('# skipping %(repository)-35s since it matches the exclude pattern: %(pattern)s' % {'repository': repo_name, 'pattern': repository_names_to_exclude_pattern})
            del repos_to_action[repo_name]
            skip_count += 1
            continue
    if skip_count:
        print('\n# skipped %s repositories' % (skip_count,))

    action_count = 0
    for repo_name in sorted(repos_to_action):
        if repos_to_action[repo_name]['URL'].startswith(github_anonymous_prefix):
            repos_to_action[repo_name]['URL'] = github_authenticated_prefix + repos_to_action[repo_name]['URL'][len(github_anonymous_prefix):]  # convert URL from anonymous clone to authenticated
        print(BASH_GIT_PREAMBLE % {'repository': repo_name, 'URL': repos_to_action[repo_name]['URL']})
        if tag_name and tag_commitmsg:
            print(BASH_GIT_TAG % {'tag_name': tag_name,
                                  'tag_commitmsg': tag_commitmsg,
                                  'HEAD': repos_to_action[repo_name]['HEAD'],
                                  'BRANCH': repos_to_action[repo_name]['BRANCH'],  # this is the original branch name (usually master)
                                  })
        if branch_name:
            print(BASH_GIT_BRANCH % {'branch_name': branch_name,  # this is the new branch name
                                     'HEAD': repos_to_action[repo_name]['HEAD'],
                                     'BRANCH': repos_to_action[repo_name]['BRANCH'],  # this is the original branch name (usually master)
                                     })
        action_count += 1

    print('\n# generated action for %s repositories' % (action_count,))
    print('\ncd ${work_dir}/..\n')

###############################################################################
# Command line processing                                                     #
###############################################################################

if __name__ == '__main__':
    generate_make_branch_tag_script()
