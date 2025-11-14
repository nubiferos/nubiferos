# Firejail base profile for NubiferOS workspaces
# This profile provides common restrictions for all cloud CLI tools

# Include common restrictions
include disable-common.inc
include disable-devel.inc
include disable-exec.inc
include disable-interpreters.inc
include disable-programs.inc
include disable-xdg.inc

# Filesystem restrictions
# Allow only necessary directories
private-cache
private-dev
private-tmp

# Network restrictions
# Allow network access (required for cloud APIs)
# Individual profiles can further restrict

# Security features
caps.drop all
ipc-namespace
netfilter
no3d
nodvd
nogroups
noinput
nonewprivs
noroot
notv
nou2f
novideo
protocol unix,inet,inet6
seccomp
seccomp.block-secondary
shell none

# X11 restrictions (for GUI tools)
x11 none

# Disable unnecessary features
disable-mnt
# blacklist /mnt
# blacklist /media

# Memory restrictions
rlimit-as 4G
rlimit-cpu 3600
rlimit-fsize 1G
rlimit-nofile 1024
rlimit-nproc 1000

# Read-only system directories
read-only /bin
read-only /sbin
read-only /usr
read-only /lib
read-only /lib64
read-only /opt
read-only /etc

# Whitelist approach for home directory
# Individual profiles will whitelist specific directories
