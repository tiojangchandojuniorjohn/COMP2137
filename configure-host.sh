#!/bin/bash

# Ignore TERM, HUP, and INT signals (as required)
trap '' TERM HUP INT

# Default verbose mode off
VERBOSE=false

# Function for verbose output
vprint() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

# Parse command-line options
while [ $# -gt 0 ]; do
    case "$1" in
        -verbose)
            VERBOSE=true
            shift
            ;;
        -name)
            DESIRED_HOSTNAME="$2"
            shift 2
            ;;
        -ip)
            DESIRED_IP="$2"
            shift 2
            ;;
        -hostentry)
            ENTRY_NAME="$2"
            ENTRY_IP="$3"
            shift 3
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

vprint "configure-host.sh started in verbose mode"

# ——— Handle -name ———
if [ -n "$DESIRED_HOSTNAME" ]; then
    CURRENT_HOSTNAME=$(hostname)
    if [ "$CURRENT_HOSTNAME" = "$DESIRED_HOSTNAME" ]; then
        vprint "Hostname already set to '$DESIRED_HOSTNAME'"
    else
        vprint "Changing hostname from '$CURRENT_HOSTNAME' to '$DESIRED_HOSTNAME'"
        echo "$DESIRED_HOSTNAME" > /etc/hostname
        sed -i "s/$CURRENT_HOSTNAME/$DESIRED_HOSTNAME/g" /etc/hosts
        hostname "$DESIRED_HOSTNAME"
        logger "configure-host.sh: hostname changed from $CURRENT_HOSTNAME to $DESIRED_HOSTNAME"
        vprint "Hostname updated successfully"
    fi
fi

# ——— Handle -ip ———
if [ -n "$DESIRED_IP" ]; then
    # Find the LAN interface that currently has a 192.168.16.x address
    LAN_IFACE=$(ip -4 addr | grep -E 'inet 192\.168\.16\.' | awk '{print $NF}' | head -n1)
    if [ -z "$LAN_IFACE" ]; then
        echo "ERROR: Could not determine LAN interface (192.168.16.x not found)" >&2
        exit 1
    fi

    CURRENT_IP=$(ip -4 addr show dev "$LAN_IFACE" | grep -oP 'inet \K[\d.]+')

    if [ "$CURRENT_IP" = "$DESIRED_IP" ]; then
        vprint "IP address on $LAN_IFACE already $DESIRED_IP"
    else
        vprint "Changing IP on $LAN_IFACE from $CURRENT_IP to $DESIRED_IP"

        # Update netplan config — only replace the exact current LAN IP/24
        NETPLAN_FILE=$(find /etc/netplan -name '*.yaml' | head -n1)
        if [ -z "$NETPLAN_FILE" ]; then
            echo "ERROR: No netplan configuration file found" >&2
            exit 1
        fi
        sed -i "s|$CURRENT_IP/24|$DESIRED_IP/24|" "$NETPLAN_FILE"

        # Apply the new configuration
        if ! netplan apply >/dev/null 2>&1; then
            vprint "netplan apply failed, running with debug..."
            netplan apply --debug
        fi

        # Update this host's own entry in /etc/hosts
        CURRENT_HOSTNAME=$(hostname)
        sed -i "/[[:space:]]$CURRENT_HOSTNAME$/d" /etc/hosts
        echo "$DESIRED_IP $CURRENT_HOSTNAME" >> /etc/hosts

        logger "configure-host.sh: IP changed on $LAN_IFACE from $CURRENT_IP to $DESIRED_IP"
        vprint "IP address updated successfully"
    fi
fi

# ——— Handle -hostentry ———
if [ -n "$ENTRY_NAME" ] && [ -n "$ENTRY_IP" ]; then
    if grep -qE "^$ENTRY_IP[[:space:]]+$ENTRY_NAME([[:space:]]|$)" /etc/hosts; then
        vprint "Host entry $ENTRY_NAME $ENTRY_IP already present"
    else
        vprint "Adding/updating host entry: $ENTRY_IP $ENTRY_NAME"
        # Remove any old lines with this hostname
        sed -i "/[[:space:]]$ENTRY_NAME$/d" /etc/hosts
        # Add the new correct line
        echo "$ENTRY_IP $ENTRY_NAME" >> /etc/hosts
        logger "configure-host.sh: added/updated host entry $ENTRY_NAME $ENTRY_IP"
        vprint "Host entry updated"
    fi
fi

vprint "configure-host.sh completed"
exit 0
