#!/bin/bash
set -e
echo "=== Starting Assignment 2 Configuration Script ==="

print_section() {
    echo -e "\n=== $1 ==="
}

print_error() {
    echo -e "ERROR: $1" >&2
    exit 1
}

print_section "Configuring Network Interface"

# Identify the interface for 192.168.16 network
INTERFACE=$(ip -br addr show | grep '192.168.16' | awk '{print $1}' | cut -d'@' -f1 || true)
if [ -z "$INTERFACE" ]; then
    # Find the interface by checking available interfaces
    INTERFACE=$(ip link show | grep -E '^[0-9]+: e.*:.*state UP' | awk '{print $2}' | cut -d':' -f1 | cut -d'@' -f1 | head -n1)
    [ -z "$INTERFACE" ] && print_error "No suitable network interface found for 192.168.16 network"
fi
echo "Found interface: $INTERFACE for 192.168.16 network"

# Backup existing netplan config
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
[ -f "$NETPLAN_FILE" ] && cp "$NETPLAN_FILE" "$NETPLAN_FILE.bak" && echo "Backed up $NETPLAN_FILE to $NETPLAN_FILE.bak"

# Create netplan configuration
cat > "$NETPLAN_FILE" << EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses:
        - 192.168.16.21/24
      routes:
        - to: 0.0.0.0/0
          via: 192.168.16.2
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

chmod 600 "$NETPLAN_FILE" && echo "Set permissions to 600 for $NETPLAN_FILE"

if netplan apply; then
    echo "Netplan configuration applied successfully"
else
    print_error "Failed to apply netplan configuration"
fi

print_section "Configuring /etc/hosts"
[ -f /etc/hosts ] && cp /etc/hosts /etc/hosts.bak && echo "Backed up /etc/hosts to /etc/hosts.bak"

if grep -q "192.168.16.21 server1" /etc/hosts; then
    echo "/etc/hosts already contains correct server1 entry"
else
    grep -v "server1" /etc/hosts > /tmp/hosts.tmp || true
    echo "192.168.16.21 server1" >> /tmp/hosts.tmp
    mv /tmp/hosts.tmp /etc/hosts && echo "Updated /etc/hosts with 192.168.16.21 server1"
fi
