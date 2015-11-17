// This script sets the job "build description" (which appears in the Jenkins web interface), if one is available
// To provide a build description, a previous build step must write a line to the Jenkins log of the form defined in the pattern below

// Note that there are two very similar scripts where we set the build description:
// (1) A script suitable for a build step in the middle of the job. This is run using a Jenkins "Execute system Groovy script" build step.
//     This is typically used in jobs that use artifacts from an earlier job: the build description reports what the job is testing
// (2) A script suitable for a post-build step at the end of the job. This is run using a Jenkins "Groovy Postbuild" post-build action.
//     This is typically used in jobs that do a materialize: the build description reports if the materialize fails due to network errors

// If you change one of the two scripts, you might need to make a matching change to the other also.

// ** NOTE ** A Groovy Postbuild step runs on the master, and hence cannot access the workspace on a slave.
// So the contents of SetBuildDescriptionPostbuild.groovy are for reference only, and are duplicated in each Jenkins job

// context when running as a system Groovy script
def currentBuild = Thread.currentThread().executable

// Look for a build description in the 20 most recent lines of the build log (reading backwards)
log = currentBuild.getLog(20).reverse()
founddesc = false
for (line in log) {
  match = (line =~ /^(append|set)-build-description: (.+)$/)
  if (match) {
    // found an instruction to append or set the build description
    founddesc = true
    break
  }
  match = (line =~ /^\[SetBuildDescription(Buildstep|Postbuild)\]/)
  if (match) {
    // don't read the log (backwards) any further, since the most recent instruction to append or set the build description has been processed
    break
  }
}

if (founddesc) {
  prevDescription = currentBuild.getDescription()
  if (prevDescription) {
    if (match[0][1] == "append") {
      reportText = "Build description was previously set; specified text appended"
      newDescription = prevDescription.trim() + "<br>\n" + match[0][2].trim()
    } else {
      reportText = "Build description was previously set; replaced by specified text"
      newDescription = match[0][2].trim()
    }
  } else {
    reportText = "Build description was not previously set; set to specified text"
    newDescription = match[0][2].trim()
  }
  currentBuild.setDescription(newDescription)
} else {
  reportText = "No new build description found to append/set"
}
out.println "[SetBuildDescriptionBuildstep] " + reportText
