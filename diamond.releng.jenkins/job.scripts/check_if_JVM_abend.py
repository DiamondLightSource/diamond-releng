###
### read the test report files (in JUnit format) and look for specific problems that require the build to be failed.
###

import fnmatch
import os
import sys

def check_if_JVM_abend(call_args):

    module_name = ""
    try:
        module_name = " (this message issued by \"%s\")" % (os.path.basename(__file__))
    except:
        pass

    if not call_args:
        print '\nERROR: Directories to check must be specified on the command line%s' % (module_name,)
        return 2

    parents = []
    test_reports = []

    for parent in call_args:
        abs_parent = os.path.abspath(parent)
        parents.append(abs_parent)
        for root, dirs, files in os.walk(abs_parent):
            for ignore_dir in ('.git', '.metadata', '.svn', 'bin', 'src', 'javadocs', 'tp'):
                if ignore_dir in dirs:
                    dirs.remove(ignore_dir)
            if os.path.basename(root) == 'test-reports':
                # find both TEST-*.xml and IGNORETHIS.xml (the latter left by test runs that crash in-flight)
                reports = fnmatch.filter(files, '*.xml')
                test_reports.extend(os.path.join(root, f) for f in reports)
    if not test_reports:
        print '\nWARNING: no test reports found in %s' % (parents,)
        return 0

    abends_found = False
    for report in sorted(test_reports):
        report_name_printed = False
        with open(report) as report_file:
            prev_line_to_print = None
            for line_nbr, line in enumerate(report_file):
                line = line.rstrip("\n").rstrip()
                if any(msg in line for msg in ("[junit] Tests FAILED (crashed)", "Forked Java VM exited abnormally", "A fatal error has been detected by the Java Runtime Environment")):
                    if not abends_found:
                        print "\n" + "*"*100
                        print "ERROR: JVM or native library crash found in test reports%s:" % module_name
                        abends_found = True
                    else:
                        print
                    if not report_name_printed:
                        print report
                        report_name_printed = True
                    if prev_line_to_print:
                        print "%s: %s" % (line_nbr, prev_line_to_print)
                    print "%s: %s" % (line_nbr+1, line)
                    prev_line_to_print = None
                else:
                    prev_line_to_print = line
    if abends_found:
        print
        print "Note: the classname= and name= in any <testcase> element may not match, and may not indicate the actual test that caused the crash"
        print "*"*100 + "\n"
        return 2
    print "VALID: no JVM or native library crash found in %s report files%s" % (len(test_reports), module_name)
    return 0

if __name__ == '__main__':
    sys.exit(check_if_JVM_abend(sys.argv[1:]))
