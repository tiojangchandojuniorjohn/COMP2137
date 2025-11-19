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

print_section "Installing Required Software"

install_package() {
    if dpkg -l | grep -q "^ii  $1 "; then
        echo "$1 is already installed"
    else
        echo "Installing $1..."
        apt-get update -y && apt-get install -y $1 || print_error "Failed installing $1"
    fi
}

install_package apache2
install_package squid

print_section "Configuring Required User Accounts"

USER_LIST="aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda dennis"

SPECIAL_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for USER in $USER_LIST; do
    echo "--- Processing user: $USER ---"

    # Create user if missing
    if id "$USER" &>/dev/null; then
        echo "User $USER already exists"
    else
        echo "Creating user $USER..."
        useradd -m -s /bin/bash "$USER" || print_error "Failed creating user: $USER"
    fi

    HOME_DIR="/home/$USER"
    SSH_DIR="$HOME_DIR/.ssh"
    AUTH_FILE="$SSH_DIR/authorized_keys"

    # Ensure .ssh directory exists
    if [ ! -d "$SSH_DIR" ]; then
        echo "Creating SSH directory for $USER"
        mkdir -p "$SSH_DIR"
        chown $USER:$USER "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi

    # Generate RSA key
    if [ ! -f "$SSH_DIR/id_rsa.pub" ]; then
        echo "Generating RSA key for $USER"
        sudo -u $USER ssh-keygen -t rsa -b 2048 -f "$SSH_DIR/id_rsa" -N ""
    fi

    # Generate ed25519 key
    if [ ! -f "$SSH_DIR/id_ed25519.pub" ]; then
        echo "Generating ed25519 key for $USER"
        sudo -u $USER ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N ""
    fi

    # Ensure authorized_keys exists
    touch "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
    chown $USER:$USER "$AUTH_FILE"

    # Add user's own keys to authorized_keys (idempotent)
    for KEYFILE in "$SSH_DIR/id_rsa.pub" "$SSH_DIR/id_ed25519.pub"; do
        PUBKEY=$(cat "$KEYFILE")
        if ! grep -qxF "$PUBKEY" "$AUTH_FILE"; then
            echo "$PUBKEY" >> "$AUTH_FILE"
        fi
    done

    # Extra key for dennis
    if [ "$USER" == "dennis" ]; then
        echo "Ensuring special key added for dennis"
        if ! grep -qxF "$SPECIAL_KEY" "$AUTH_FILE"; then
            echo "$SPECIAL_KEY" >> "$AUTH_FILE"
        fi

        # Ensure sudo access
        usermod -aG sudo dennis
        echo "Added dennis to sudo group"
    fi

done

print_section "Assignment 2 Configuration Complete!"
echo "Script finished successfully."
