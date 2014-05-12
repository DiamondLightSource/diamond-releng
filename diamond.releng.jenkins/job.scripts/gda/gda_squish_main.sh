# specify the environment
. ${WORKSPACE}/diamond-releng.git/diamond.releng.jenkins/job.scripts/set-environment.sh GDA-${GDA_release}-environment-variables.properties

# squish_setup requires Python 2.7
module load python/2.7.4
python ${WORKSPACE}/diamond-releng.git/diamond.releng.squish/squish_setup_gda.py

. ${WORKSPACE}/squish_framework/squishhostsetup.sh

. ${WORKSPACE}/diamond-releng.git/diamond.releng.squish/gda/servers_start.sh
ps -w -eo pid,ppid,pgid,thcount,nice,pcpu,pmem,start,stat,user,args | grep -E "^ *PID |java " | grep -v " slave.jar" | grep -v "grep "
    
## . ${WORKSPACE}/squish_framework/squishhostrun.sh

. ${WORKSPACE}/diamond-releng.git/diamond.releng.squish/gda/servers_stop.sh
ps -w -eo pid,ppid,pgid,thcount,nice,pcpu,pmem,start,stat,user,args | grep -E "^ *PID |java " | grep -v " slave.jar" | grep -v "grep "

python ${WORKSPACE}/diamond-releng.git/diamond.releng.squish/gda/check_server_logs.py || true

## . ${WORKSPACE}/squish_framework/jenkinswrapup.sh

