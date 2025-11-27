#!/bin/bash

# lab3.sh – final version (fixed local /etc/hosts updates)

VERBOSE=false
if [ "$1" = "-verbose" ]; then
    VERBOSE=true
    shift
fi

VERBOSE_FLAG=""
$VERBOSE && VERBOSE_FLAG="-verbose"

run() {
    if $VERBOSE; then
        echo "=== Running: $*"
    fi
    "$@" 
    if [ $? -ne 0 ]; then
        echo "ERROR: Command failed: $*"
        exit 1
    fi
}

SERVER1="remoteadmin@172.16.1.241"
SERVER2="remoteadmin@172.16.1.242"

# Deploy script
run scp configure-host.sh "$SERVER1":/root/
run scp configure-host.sh "$SERVER2":/root/

# Configure the two servers
run ssh "$SERVER1" -- /root/configure-host.sh $VERBOSE_FLAG \
    -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4

run ssh "$SERVER2" -- /root/configure-host.sh $VERBOSE_FLAG \
    -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3

# Update local /etc/hosts on the desktop VM (requires sudo)
if $VERBOSE; then
    echo "=== Updating local /etc/hosts (sudo required)"
fi

sudo ./configure-host.sh -hostentry loghost 192.168.16.3
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add loghost entry to local /etc/hosts"
    exit 1
fi

sudo ./configure-host.sh -hostentry webhost 192.168.16.4
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add webhost entry to local /etc/hosts"
    exit 1
fi

echo "All configuration completed successfully!"
exit 0
