#!/usr/bin/env python

###
### check that the .zip files of the Dawn product have the correct structure (see Jira DASCTEST-70 and DASCTEST-142)
###

import optparse
import os
import sys
import zipfile

MUST_HAVE = 1
OPTIONAL = 2
MUST_NOT_HAVE = 3

def main(args):
    """ Process any command line arguments and run program.
        call_args[0] == the directory the script is running from.
        call_args[1:] == command options """

    parser = optparse.OptionParser(usage="usage: %prog [options] file(s) to check",
        description="Check that a zipped Dawn product has the required structure")
    parser.disable_interspersed_args()
    parser.formatter.help_position = parser.formatter.max_help_position = 46  # improve look of help
    if not os.environ.has_key('COLUMNS'):  # typically this is not passed from the shell to the child process (Python)
        parser.formatter.width = 120  # so avoid the default of 80 and assume a wider terminal (improve look of help)
    parser.add_option('-d', '--dir', dest='dir_requirement',
                      type='choice', choices=('MUST_HAVE','OPTIONAL','MUST_NOT_HAVE'), default='OPTIONAL',
                      help='Whether the .zip file must contain a single parent directory')
    parser.add_option('-j', '--jre', dest='jre_requirement',
                      type='choice', choices=('MUST_HAVE','OPTIONAL','MUST_NOT_HAVE'), default='OPTIONAL',
                      help='Whether the .zip file must contain a JRE')


    if len(args) == 1:
        parser.print_help()
        return 0

    (options, filenames) = parser.parse_args(args[1:])
    if not filenames:
        print 'ERROR: you need to supply one or more zip filenames to analyze'
        return 1

    tested_count = failure_count = 0
    for filename in filenames:
        filename_path = os.path.abspath(os.path.expanduser(filename))
        print 'Checking %s' % (filename_path,)
        with zipfile.ZipFile(filename_path, 'r') as dawnzip:
            namelist = dawnzip.namelist()
            direct_descendents_dirs = [filename for filename in namelist if (filename.count('/') == 1) and filename.endswith('/')]
            direct_descendents_files = [filename for filename in namelist if (filename.count('/') == 0)]
            has_dir = (len(direct_descendents_dirs) == 1) and (len(direct_descendents_files) == 0)
            if ((options.dir_requirement == 'MUST_NOT_HAVE' and has_dir) or
                (options.dir_requirement == 'MUST_HAVE' and (not has_dir))):
                has_dir_valid = False
            else:
                has_dir_valid = True
            print '  dir_requirement=%-14s: %s' % (options.dir_requirement, ('failed','passed')[int(has_dir_valid)])

            if has_dir:
                jre_path = direct_descendents_dirs[0] + 'jre/bin/'
            else:
                jre_path = 'jre/bin/'
            try:
                has_jre = bool(dawnzip.getinfo(jre_path))
            except KeyError:
                has_jre = False
            if ((options.jre_requirement == 'MUST_NOT_HAVE' and has_jre) or
                (options.jre_requirement == 'MUST_HAVE' and (not has_jre))):
                has_jre_valid = False
            else:
                has_jre_valid = True
            print '  jre_requirement=%-14s: %s' % (options.jre_requirement, ('failed','passed')[int(has_jre_valid)])

            tested_count += 1
            if not (has_dir_valid and has_jre_valid):
                failure_count += 1

    print '\nFiles Checked: %d' % (tested_count,)
    print 'Files Invalid: %d' % (failure_count,)

    return min(failure_count,1)

if __name__ == "__main__":
    sys.exit(main(sys.argv))
