// This Groovy script must be run using a Jenkins "Execute system Groovy script" build step
// A previous step must write a line in the log of the form defined in "pattern" below

def currentBuild = Thread.currentThread().executable
def pattern = /^set-build-description: (.+)$/

// Parsing 20 most recent lines of the build log
log = currentBuild.getLog(20)
for (line in log) {
    match = (line =~ pattern)
   if (match) {
     currentBuild.setDescription(match[0][1])
     out.println "[set-build-description.groovy] Build description was set to: " + match[0][1]
     break
  }
}
