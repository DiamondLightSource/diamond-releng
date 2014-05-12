import socket, time, subprocess

HOST="g18-sc-serv-03"
PORTS=range(5950,5970)

runningprocs = dict()
while True:
    for port in PORTS:
        if port in runningprocs:
            runningprocs[port].poll()
            if runningprocs[port].returncode is not None:
                print "%s:%d has closed" % (HOST, port)
                del runningprocs[port]
                
        if not port in runningprocs:
            sd = socket.socket(socket.AF_INET, socket.SOCK_STREAM)        
            try:
                # test if the given host:port is open
                sd.connect((HOST, port))
            except socket.error:
                pass
            else:
                sd.close()
                print "%s:%d is available, launching vncviewer" % (HOST, port)
                proc = subprocess.Popen(['vncviewer', '--ViewOnly=1', '--PasswordFile=vncpassword', '%s:%d' % (HOST, port)])
                runningprocs[port] = proc
    # take a break before checking all ports again
    time.sleep(10)
                
                