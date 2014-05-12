The VMs are all configured to share their screen over vnc on port 5900 (default VNC) with
a password of squish. VMWare does not limit connections to view only, therefore the
connections should be made view only when interaction is not needed.

To recreate the vncpasswd use tightvncpasswd and enter a password up to 8 characters long.
e.g:
$ tightvncpasswd vncpassword
Password: squish
Verify: squish
Would you like to enter a view-only password (y/n)? y
Password: squishv
Verify: squishv


To monitor the build machine with VNC, use something like this, replacing localhost
with the build machine name if accessible non-locally.
while true; do vncviewer --ViewOnly=1 --PasswordFile=vncpassword localhost; sleep 1; done

vncviewer comes from package xvnc4viewer, I was using version 4.1.1+xorg4.3.0-37ubuntu3
tightvncpasswd comes from package tightvncserver, I was using version 1.3.9-6.2
