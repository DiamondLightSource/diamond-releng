// This script sets the job "build description" (which appears in the Jenkins web interface), if one is available
// To provide a build description, a previous build step must write a line in the log of the form defined in "pattern" below

// Note that there are two very similar scripts where we set the build description:
// (1) A script suitable for a build step in the middle of the job. This is run using a Jenkins "Execute system Groovy script" build step.
//     This is typically used in jobs that use artifacts from an earlier job: the build description reports what the job is testing
// (2) A script suitable for a post-build step at the end of the job. This is run using a Jenkins "Groovy Postbuild" post-build action.
//     This is typically used in jobs that do a materialize: the build description reports if the materialize fails due to network errors

// If you change one of the two scripts, you might need to make a matching change to the other also.

// ** NOTE ** A Groovy Postbuild step runs on the master, and hence cannot access the workspace on a slave.
// So the contents of SetBuildDescriptionPostbuild.groovy are for reference only, and are duplicated in each Jenkins job

// context when running as a post-build Groovy script
def currentBuild = manager.build

def pattern = /^set-build-description: (.+)$/

// Look for a build description in the 20 most recent lines of the build log
log = currentBuild.getLog(20)
founddesc = false
for (line in log) {
   match = (line =~ pattern)
   if (match) {
     founddesc = true
     break
   }
}

if (founddesc) {
   currentBuild.setDescription(match[0][1])
   manager.listener.logger.println "[SetBuildDescriptionPostbuild] Build description was set to: " + match[0][1]
} else {
   manager.listener.logger.println "[SetBuildDescriptionPostbuild] No build description found to set"
}
