'''
Reads a list of changes that were tested together, and writes a bash script to post the result back to Gerrit 

Testing notes:
   Set environment variables something like this:
      export WORKSPACE=
      export BUILD_URL=http://jenkins.diamond.ac.uk:8080/job/GDA.master-junit.tests-gerrit.manual/19/
      export gerrit_verified_option='Set Gerrit "Verified", based on test job pass/fail'
'''

from __future__ import print_function
import datetime
import itertools
import json
import operator
import os
import os.path
import stat
import sys
import urllib
import urllib2

CHANGE_LIST_FILE_PATH = os.path.abspath(os.path.expanduser(os.path.join(os.environ['WORKSPACE'], 'artifacts_to_archive', 'gerrit_changes_tested.txt')))
POST_FUNCTION_FILE_PATH = os.path.abspath(os.path.expanduser(os.path.join(os.environ['WORKSPACE'], 'artifacts_to_archive', 'gerrit_changes_post_result.txt')))

def write_script_file():

    # get whether this job failed or succeeded
    request = urllib2.Request(os.environ['BUILD_URL'] + 'api/json/?tree=result')
    jenkins_result_json = urllib2.urlopen(request).read()
    jenkins_result = json.loads(jenkins_result_json)['result']  # possible values are SUCCESS, ABORTED, FAILURE

    # get build parameter gerrit_verified_option, specified as a build parameter
    # the option will be one of these (defined in the Jenkins configuration)
    #    Leave any Gerrit "Verified" status unchanged
    #    Set Gerrit "Verified", based on test job pass/fail
    #    Set Gerrit "Verified", but only if test job passes
    #    Set Gerrit "Verified", but only if test job fails
    gerrit_verified_option = os.environ['gerrit_verified_option']

    # build the review command to send to Gerrit
    review_command_verified = ''
    if jenkins_result == 'SUCCESS':
        review_command_message = '--message \'"Build Successful ' + os.environ.get('BUILD_URL','') + '"\''
        if any(s in gerrit_verified_option for s in ('only if test job passes', 'based on test job pass/fail')):
            review_command_verified = '--verified +1'
    elif jenkins_result in ('UNSTABLE', 'FAILURE'):
        review_command_message = '--message \'"Build Failed ' + os.environ.get('BUILD_URL','') + '"\''
        if any(s in gerrit_verified_option for s in ('only if test job fails', 'based on test job pass/fail')):
            review_command_verified = '--verified -1'
    elif jenkins_result == 'ABORTED':
        review_command_message = '--message \'"Build Aborted ' + os.environ.get('BUILD_URL','') + '"\''
    else:
        review_command_message = '--message \'"Jenkins got unknown status ' + jenkins_result + ' ' + os.environ.get('BUILD_URL','') + '"\''

    # generate and write the artifact file (a record of what changes we are testing) and the bash script (which actually fetches the changes to test)
    with open(CHANGE_LIST_FILE_PATH, 'r') as change_list_file:
     with open(POST_FUNCTION_FILE_PATH, 'w') as script_file:
        generated_header = ('### File generated at ' + datetime.datetime.now().strftime('%a, %Y/%m/%d %H:%M') + 
            ' in Jenkins ' + os.environ.get('BUILD_TAG','<build_tag>') + ' (' + os.environ.get('BUILD_URL','<build_url>') + ')')
        script_file.write(generated_header + '\n\ngerrit_changes_post_result () {\n')

        for line in change_list_file:
            if line.startswith('#'):
                continue
            (project, change, current_revision_number, change_id, refspec, repo_branch) = (item for item in line.rstrip().split('***') if item)
            # generate the commands necessary to post the test result for this change
            script_file.write('    ssh -p ${GERRIT_PORT} ${GERRIT_HOST} gerrit review %s,%s -p %s -n NONE %s %s\n'
                              % (change, current_revision_number, project, review_command_message, review_command_verified))

        script_file.write('}\n\n')

    print('Done: read report file from', CHANGE_LIST_FILE_PATH)
    print('Done: wrote script file to', POST_FUNCTION_FILE_PATH)

if __name__ == '__main__':
    return_code = write_script_file()
    sys.exit(return_code)
