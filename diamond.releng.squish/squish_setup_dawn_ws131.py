#!/usr/bin/env python
# -*- encoding=utf8 -*-
'''
Runs on the Jenkins slave (always a Linux machine), and dispatches Squish tests on either itself, or another machine (typically a VM, possibly a different platform)

'''

import os
import sys

import squish_manager

#=====================================================================================================================#

if __name__ == '__main__':

    manager = squish_manager.SquishTestManager(squish_hostname='ws131.diamond.ac.uk', squish_platform='linux64', use_epdfree=True, jenkins_workspace=os.environ['WORKSPACE'])
    manager.specify_application('dawn', 'DawnDiamond-.+')

    try:
        sys.exit(manager.jenkins_slave_setup())
    except squish_manager.SquishTestSetupError, e:
        print(e)
        sys.exit(3)
    except KeyboardInterrupt:
        if len(sys.argv) > 1:
            print("\nOperation (%s) interrupted and will be abandoned." % ' '.join(sys.argv[1:]))
        else:
            print("\nOperation interrupted and will be abandoned")
        sys.exit(3)
