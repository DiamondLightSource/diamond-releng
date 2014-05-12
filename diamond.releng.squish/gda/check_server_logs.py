###
### read the log files written by the Jenkins server test, and fail the build if there are errors
###

import os
import re
import unittest

import xmlrunner

class ServerTestLogsCheck(unittest.TestCase):

    def test_no_server_errors(self):
        """ Reads the server log files, and reports any errors (exceptions, etc)"""

        # patterns that, if matched, indicate an error
        patterns = ("^.*ERROR \[\S+].*",  # match something like "2009-08-21 13:41:55,581 ERROR [gda.util.ObjectServer]"
                    "^.*Exception in \S+.*",  # match something like "gda.factory.FactoryException: Exception in ObjectCreator"
                    ".*Traceback \(most recent call last\).*",  # matches a Python traceback, something like "WARN  [gda.jython.GDAInteractiveConsole]", note logs as WARN not ERROR
                    ".*FAILED.*",  # for errors raised in localstation
                    )
        patterns_re = map(re.compile, patterns)
        errors_found = False

        log_dir = os.path.abspath("server_test_logs")
        self.failUnless(os.path.isdir(log_dir), "ERROR: directory \"%s\" does not exist" % log_dir)

        print "\n\nChecking log files in %s ..." % log_dir
        log_count = 0
        for entry in sorted(os.listdir(log_dir)):
            log = os.path.join(log_dir, entry)
            if os.path.isfile(log) and log.endswith("log") and (entry != "0-stop_old_servers.log"):
                print "processing %s" % log
                log_count += 1
                log_has_errors = False
                line_nbr = 0
                seen_Server_initialisation_complete = False
                with open(log) as log_file:
                    for line_nbr, line in enumerate(log_file):
                        seen_Server_initialisation_complete = seen_Server_initialisation_complete or ("Server initialisation complete" in line)  # Object Server only
                        for pattern in patterns_re:
                            if pattern.match(line.strip()):
                                # bunch of things that look like errors, but which can be ignored
                                if all([text in line for text in ("ERROR [gda.device.motor.MotorBase] - Motor Position File", "not found - setting", "creating new file.")]):
                                    continue
                                log_has_errors = True
                                print "%5s  %s" % (line_nbr+1, line.strip())
                if line_nbr < 9:
                    log_has_errors = True
                    print "       Log shorter than possible for a valid test run (%s lines), check for problems " % (line_nbr+1,)
                if ("stop_" not in entry) and ("objectserver" in entry) and not seen_Server_initialisation_complete:
                    log_has_errors = True
                    print "       \"Server initialisation complete\" message expected but not seen in file (%s lines checked)" % (line_nbr+1,)
                if log_has_errors:
                    errors_found = True
        
        self.failIf(errors_found,"ERROR: Errors found in log files in \"%s\")" % log_dir)
        self.failIf(log_count < 8,"ERROR: expected to process at least 8 log files, but only %s found in \"%s\"" % (log_count, log_dir))
        print "Valid: No errors found in %s log files in \"%s\"" % (log_count, log_dir)
        return

if __name__ == '__main__':
    unittest.main(testRunner=xmlrunner.XMLTestRunner(output='server_test_logs'))
