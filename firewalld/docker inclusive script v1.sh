#!/bin/bash
# Improved Fedora 41 Firewall Hardening Script (firewalld 2.2.3 compatible)
# Security Targets:
# 1. Block all local network access to services unless explicitly allowed
# 2. Allow localhost full access
# 3. Implement proper port knocking for SSH access
# 4. Maintain network auto-switching functionality
# 5. Secure Docker services by default

# --- Configuration ---
FEDORA_ZONE="FedoraWorkstation"
FORTRESS_ZONE="fortress"
KNOCK_PORTS=(7000 8000 9000)  # Port knocking sequence
SSH_PORT=22
DOCKER_ZONE="docker"

# --- Firewalld Compatibility Setup ---
set -e
FIREWALLD_VERSION=$(firewall-cmd --version 2>/dev/null | cut -d' ' -f1)

# --- Helper Functions ---
add_direct_rule() {
    family=$1
    chain=$2
    rule=$3
    echo "   - [Direct] $family $chain: $rule"
    firewall-cmd --permanent --direct --add-rule $family filter $chain 0 $rule
}

log_step() {
    echo
    echo "🔶 $1"
}

# --- Initial Checks ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit 1
fi

echo "🛡️ Starting Improved Fedora 41 Firewall Hardening (firewalld ${FIREWALLD_VERSION})"

# --- Backup Original Config ---
BACKUP_BASE="/root/firewalld-backups"
BACKUP_DIR="${BACKUP_BASE}/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

log_step "Backing up current configuration..."
cp -a /etc/firewalld "$BACKUP_DIR/" 2>/dev/null || echo "⚠️  Failed to copy firewalld config"
echo "✅ Backup complete: ${BACKUP_DIR}"

# =========================================================================
# 0. RESET EXISTING CONFIG (Important for clean application)
# =========================================================================
log_step "Resetting existing firewall configuration..."

# Remove any existing custom configurations that might interfere
firewall-cmd --permanent --zone=${FEDORA_ZONE} --remove-source=127.0.0.1/8 2>/dev/null || true
firewall-cmd --permanent --zone=${FEDORA_ZONE} --remove-source=::1/128 2>/dev/null || true

# Remove all rich rules from the default zone
current_rules=$(firewall-cmd --permanent --zone=${FEDORA_ZONE} --list-rich-rules)
if [ -n "$current_rules" ]; then
    echo "$current_rules" | while IFS= read -r rule; do
        [ -n "$rule" ] && firewall-cmd --permanent --zone=${FEDORA_ZONE} --remove-rich-rule="$rule"
    done
fi

# Reset docker zone as well
firewall-cmd --permanent --zone=${DOCKER_ZONE} --set-target=ACCEPT # Temporarily set to ACCEPT for removal
firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-source=127.0.0.1/8 2>/dev/null || true
firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-source=::1/128 2>/dev/null || true
firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-service=dhcp 2>/dev/null || true
firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-service=dhcpv6-client 2>/dev/null || true
firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-service=dns 2>/dev/null || true
current_docker_rules=$(firewall-cmd --permanent --zone=${DOCKER_ZONE} --list-rich-rules)
if [ -n "$current_docker_rules" ]; then
    echo "$current_docker_rules" | while IFS= read -r rule; do
        [ -n "$rule" ] && firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-rich-rule="$rule"
    done
fi
firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-port=53/udp 2>/dev/null || true
firewall-cmd --permanent --zone=${DOCKER_ZONE} --remove-port=5053/udp 2>/dev/null || true

# =========================================================================
# 1. HARDEN DEFAULT ZONE (FedoraWorkstation)
# =========================================================================
log_step "Configuring ${FEDORA_ZONE} zone with proper network isolation..."

# Set to REJECT - this is critical for blocking network access by default
firewall-cmd --permanent --zone=${FEDORA_ZONE} --set-target=REJECT

# Remove existing ports/services we don't need
firewall-cmd --permanent --zone=${FEDORA_ZONE} --remove-service=ssh 2>/dev/null || true
for port in "${KNOCK_PORTS[@]}"; do
    firewall-cmd --permanent --zone=${FEDORA_ZONE} --remove-port=${port}/tcp 2>/dev/null || true
done

# Keep essential services (DHCPv6 client for network connectivity)
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-service=dhcpv6-client

# Block ICMP redirects (security measure)
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-icmp-block=redirect

# Enable masquerading for potential container use (might need to be in docker zone instead, see below)
# firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-masquerade

# *** IMPORTANT: Create the proper localhost exception rules ***
# This allows your local apps to connect to their own services
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" accept'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv6" source address="::1" accept'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv6" source address="::1/128" accept'

# Port knocking configuration
# Log each knock and limit rate
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule="rule family=\"ipv4\" port port=\"${KNOCK_PORTS[0]}\" protocol=\"tcp\" log prefix=\"KNOCK1: \" limit value=\"5/m\" accept"
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule="rule family=\"ipv4\" port port=\"${KNOCK_PORTS[1]}\" protocol=\"tcp\" log prefix=\"KNOCK2: \" limit value=\"5/m\" accept"
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule="rule family=\"ipv4\" port port=\"${KNOCK_PORTS[2]}\" protocol=\"tcp\" log prefix=\"KNOCK3: \" limit value=\"5/m\" accept"

# Block common service ports by default to ensure they're not accessible from the network
# These are examples - add any ports you commonly use for services
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" port port="3000" protocol="tcp" reject'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" port port="5000" protocol="tcp" reject'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" port port="8080" protocol="tcp" reject'

# Direct rules for advanced protection
add_direct_rule ipv4 INPUT "-m conntrack --ctstate INVALID -j DROP"
add_direct_rule ipv6 INPUT "-m conntrack --ctstate INVALID -j DROP"

# Block spoofed local traffic from non-loopback interfaces
add_direct_rule ipv4 INPUT "! -i lo -s 127.0.0.0/8 -j DROP"
add_direct_rule ipv6 INPUT "! -i lo -s ::1/128 -j DROP"

# SYN Flood protection
add_direct_rule ipv4 INPUT "-p tcp --syn -m limit --limit 15/s -j ACCEPT"
add_direct_rule ipv6 INPUT "-p tcp --syn -m limit --limit 15/s -j ACCEPT"

# Block port scans
add_direct_rule ipv4 INPUT "-m recent --name portscan --rcheck --seconds 86400 -j DROP"
add_direct_rule ipv4 INPUT "-m recent --name portscan --remove"
add_direct_rule ipv4 INPUT "-p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK RST -m limit --limit 1/s -j ACCEPT"
add_direct_rule ipv4 INPUT "-p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK RST -m recent --name portscan --set -j DROP"

# =========================================================================
# 2. FORTRESS ZONE (Zero-Trust Configuration)
# =========================================================================
log_step "Creating ${FORTRESS_ZONE} zone for untrusted networks..."

# Zone creation
firewall-cmd --permanent --new-zone=${FORTRESS_ZONE} 2>/dev/null || true
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --set-target=DROP

# Essential outbound rules - only allow DNS, HTTP, and HTTPS
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv4" port port="53" protocol="tcp" accept'
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv4" port port="53" protocol="udp" accept'
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv4" port port="80" protocol="tcp" accept'
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv4" port port="443" protocol="tcp" accept'

# IPv6 rules
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv6" port port="53" protocol="tcp" accept'
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv6" port port="53" protocol="udp" accept'
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv6" port port="80" protocol="tcp" accept'
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule='rule family="ipv6" port port="443" protocol="tcp" accept'

# Allow DHCPv6 client (essential for IPv6 connectivity)
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-service=dhcpv6-client

# Explicitly deny all other traffic

# =========================================================================
# 3. IMPROVED PORT KNOCKING SETUP
# =========================================================================
log_step "Setting up improved port knocking for SSH access..."

# Install tcpdump if not present
if ! command -v tcpdump &>/dev/null; then
    echo "Installing tcpdump for knock detection..."
    dnf install -y tcpdump
fi

# Create improved knockd script
cat > /usr/local/bin/knockd-listener <<'EOF'
#!/bin/bash
# Improved Port Knock Daemon for firewalld 2.2.3
# Provides a more reliable port knocking mechanism

# Configuration
KNOCK_SEQUENCE=(7000 8000 9000)  # Knock sequence ports
SSH_PORT=22                      # The port to open upon successful knock
OPEN_DURATION=30                 # How long to keep the port open (seconds)
LOG_FILE="/var/log/knockd.log"   # Log file location

# Ensure log file exists and is writable
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

echo "$(date) - Port knock daemon started. Monitoring sequence: ${KNOCK_SEQUENCE[*]}" >> "$LOG_FILE"

# Create a tracking directory for knock state
TRACK_DIR="/tmp/knockd-state"
mkdir -p "$TRACK_DIR"
chmod 700 "$TRACK_DIR"

# Function to clean up old tracking files
cleanup_old_files() {
    find "$TRACK_DIR" -type f -mmin +5 -exec rm {} \;
}

# Run cleanup every 5 minutes
(while true; do
    sleep 300
    cleanup_old_files
done) &

# Use tcpdump to monitor the knock sequence
tcpdump -i any -n "tcp and ($(for port in "${KNOCK_SEQUENCE[@]}"; do echo -n "port $port or "; done | sed 's/ or $//'))" 2>/dev/null | while read line; do
    # Extract source IP and destination port
    if [[ "$line" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+).*[0-9]+\.([0-9]+) ]]; then
        SRC_IP="${BASH_REMATCH[1]}"
        SRC_PORT="${BASH_REMATCH[2]}"
        DST_PORT="${BASH_REMATCH[3]}"

        # Skip if source is localhost
        [[ "$SRC_IP" == "127.0.0.1" ]] && continue

        # Initialize tracking file if it doesn't exist
        TRACK_FILE="$TRACK_DIR/$SRC_IP"
        if [[ ! -f "$TRACK_FILE" ]]; then
            echo "0" > "$TRACK_FILE"
        fi

        # Get current position in sequence
        CURRENT_POS=$(cat "$TRACK_FILE")
        EXPECTED_PORT=${KNOCK_SEQUENCE[$CURRENT_POS]}

        # Check if this is the expected port in sequence
        if [[ "$DST_PORT" == "$EXPECTED_PORT" ]]; then
            # Move to next position in sequence
            NEXT_POS=$((CURRENT_POS + 1))

            # Check if sequence is complete
            if [[ $NEXT_POS -ge ${#KNOCK_SEQUENCE[@]} ]]; then
                echo "$(date) - Successful knock sequence from $SRC_IP" >> "$LOG_FILE"

                # Open the SSH port temporarily for this specific IP
                firewall-cmd --zone=FedoraWorkstation --add-rich-rule="rule family=ipv4 source address=$SRC_IP port port=$SSH_PORT protocol=tcp accept" --timeout=$OPEN_DURATION

                # Reset the sequence
                echo "0" > "$TRACK_FILE"
            else
                # Update position in sequence
                echo "$NEXT_POS" > "$TRACK_FILE"
                echo "$(date) - $SRC_IP completed knock $((CURRENT_POS + 1)) of ${#KNOCK_SEQUENCE[@]}" >> "$LOG_FILE"
            fi
        else
            # Wrong sequence - reset
            echo "0" > "$TRACK_FILE"
            echo "$(date) - $SRC_IP failed knock sequence (expected port $EXPECTED_PORT, got $DST_PORT)" >> "$LOG_FILE"
        fi
    fi
done
EOF

chmod +x /usr/local/bin/knockd-listener

# Create systemd service
cat > /etc/systemd/system/knockd.service <<EOF
[Unit]
Description=Port Knock Daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/knockd-listener
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable knockd.service
systemctl restart knockd.service

# =========================================================================
# 4. NETWORK AUTO-SWITCHING
# =========================================================================
log_step "Configuring Network Auto-Switching..."

# Create improved switcher script
cat > /usr/local/bin/firewall-switcher <<'EOF'
#!/bin/bash
# Network Auto-Switching Script for Firewalld
# Automatically switches between firewall zones based on network environment

# Configuration
TRUSTED_NETWORKS=("Innovus Office" "Wifi" "coast-white")  # Add your trusted network SSIDs here
NORMAL_ZONE="FedoraWorkstation"
SECURE_ZONE="fortress"
LOG_FILE="/var/log/firewall-switcher.log"

# Function to log with timestamp
log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Ensure log file exists
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

# Get the main network interface
MAIN_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)

# Detect current network environment
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | cut -d: -f2)
VPN_ACTIVE=$(ip tuntap show | grep -c tun0)

# Get current zone for comparison
CURRENT_ZONE=$(firewall-cmd --get-default-zone)

# Determine which zone should be active
if [ $VPN_ACTIVE -gt 0 ]; then
    TARGET_ZONE=${NORMAL_ZONE}
    REASON="VPN active"
elif [ -z "$CURRENT_SSID" ]; then
    TARGET_ZONE=${SECURE_ZONE}
    REASON="No wireless network"
else
    # Check if current SSID is in trusted networks list
    IS_TRUSTED=0
    for network in "${TRUSTED_NETWORKS[@]}"; do
        if [ "$network" = "$CURRENT_SSID" ]; then
            IS_TRUSTED=1
            break
        fi
    done

    if [ $IS_TRUSTED -eq 1 ]; then
        TARGET_ZONE=${NORMAL_ZONE}
        REASON="Trusted network: $CURRENT_SSID"
    else
        TARGET_ZONE=${SECURE_ZONE}
        REASON="Untrusted network: $CURRENT_SSID"
    fi
fi

# Only switch if needed
if [ "$CURRENT_ZONE" != "$TARGET_ZONE" ]; then
    log_message "Switching from $CURRENT_ZONE to $TARGET_ZONE ($REASON)"

    # Handle interface assignments correctly
    if [ -n "$MAIN_INTERFACE" ]; then
        # Remove interface from current assignment
        current_zone=$(firewall-cmd --get-zone-of-interface="$MAIN_INTERFACE" 2>/dev/null)
        if [ -n "$current_zone" ]; then
            firewall-cmd --zone="$current_zone" --remove-interface="$MAIN_INTERFACE"
        fi

        # Add interface to target zone
        firewall-cmd --zone="$TARGET_ZONE" --add-interface="$MAIN_INTERFACE"
    fi

    # Set default zone
    firewall-cmd --set-default-zone=${TARGET_ZONE}

    # Notify user if possible
    if command -v notify-send &>/dev/null; then
        notify-send "Firewall Zone Changed" "Switched to $TARGET_ZONE zone ($REASON)"
    fi
else
    log_message "Staying in $CURRENT_ZONE zone ($REASON)"
fi
EOF

chmod +x /usr/local/bin/firewall-switcher

# Create NetworkManager dispatcher
cat > /etc/NetworkManager/dispatcher.d/99-firewall-switch <<'EOF'
#!/bin/bash
# NetworkManager dispatcher script for firewall zone switching

# Only run on these events
if [ "$2" = "up" ] || [ "$2" = "down" ] || [ "$2" = "vpn-up" ] || [ "$2" = "vpn-down" ]; then
    /usr/local/bin/firewall-switcher
fi
EOF

chmod +x /etc/NetworkManager/dispatcher.d/99-firewall-switch

# Run it once to set initial state
/usr/local/bin/firewall-switcher

# =========================================================================
# 5. CONFIGURE DOCKER ZONE
# =========================================================================
log_step "Configuring ${DOCKER_ZONE} zone for secure container access..."

# Set target to REJECT
firewall-cmd --permanent --zone=${DOCKER_ZONE} --set-target=REJECT

# Allow localhost access
firewall-cmd --permanent --zone=${DOCKER_ZONE} --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'
firewall-cmd --permanent --zone=${DOCKER_ZONE} --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" accept'
firewall-cmd --permanent --zone=${DOCKER_ZONE} --add-rich-rule='rule family="ipv6" source address="::1" accept'
firewall-cmd --permanent --zone=${DOCKER_ZONE} --add-rich-rule='rule family="ipv6" source address="::1/128" accept'

# Enable masquerade if your containers need outbound internet access
firewall-cmd --permanent --zone=${DOCKER_ZONE} --add-masquerade

# =========================================================================
# 6. CREATE A TRUSTED ZONE
# =========================================================================
log_step "Configuring trusted zone..."

# Setup trusted zone if needed (for when you explicitly want network access)
firewall-cmd --permanent --zone=trusted --set-target=ACCEPT
firewall-cmd --permanent --zone=trusted --add-service=ssh
firewall-cmd --permanent --zone=trusted --add-service=dhcpv6-client

# =========================================================================
# 7. SERVICE PORT ENABLER UTILITY (Modified to handle docker zone)
# =========================================================================
log_step "Creating service port enabler utility..."

# Create a utility script to easily enable/disable ports for services
cat > /usr/local/bin/service-port <<'EOF'
#!/bin/bash
# Service Port Enabler/Disabler Utility
# Usage: service-port [enable|disable] PORT PROTOCOL [SOURCE] [ZONE]
# Default ZONE is FedoraWorkstation, use 'docker' to target docker containers

ACTION=$1
PORT=$2
PROTO=$3
SOURCE=$4
ZONE="${5:-FedoraWorkstation}" # Default to FedoraWorkstation if no zone provided

if [ -z "$ACTION" ] || [ -z "$PORT" ] || [ -z "$PROTO" ]; then
    echo "Usage: service-port [enable|disable] PORT PROTOCOL [SOURCE] [ZONE]"
    echo "Example: service-port enable 8080 tcp"
    echo "Example: service-port enable 8080 tcp 192.168.1.5"
    echo "Example: service-port enable 80 tcp - docker" # Enable port 80 for all on docker
    echo "Example: service-port enable 80 tcp 192.168.1.10 docker" # Enable port 80 for specific IP on docker
    exit 1
fi

if [ "$ACTION" = "enable" ]; then
    if [ "$ZONE" = "docker" ]; then
        if [ -n "$SOURCE" ]; then
            # Enable port only for specific source IP in docker zone
            firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"$PROTO\" accept"
            echo "Enabled port $PORT/$PROTO for source $SOURCE in zone $ZONE"
        else
            # Enable port for all clients in docker zone
            firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO
            echo "Enabled port $PORT/$PROTO for all clients in zone $ZONE"
        fi
    else
        if [ -n "$SOURCE" ]; then
            # Enable port only for specific source IP in FedoraWorkstation zone
            firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"$PROTO\" accept"
            echo "Enabled port $PORT/$PROTO for source $SOURCE in zone $ZONE"
        else
            # Enable port for all clients in FedoraWorkstation zone
            firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO
            echo "Enabled port $PORT/$PROTO for all clients in zone $ZONE"
        fi
    fi
elif [ "$ACTION" = "disable" ]; then
    if [ "$ZONE" = "docker" ]; then
        if [ -n "$SOURCE" ]; then
            # Remove specific source rule from docker zone
            firewall-cmd --zone=$ZONE --remove-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"$PROTO\" accept"
            echo "Disabled port $PORT/$PROTO for source $SOURCE in zone $ZONE"
        else
            # Disable port for all in docker zone
            firewall-cmd --zone=$ZONE --remove-port=$PORT/$PROTO
            echo "Disabled port $PORT/$PROTO for all clients in zone $ZONE"
        fi
    else
        if [ -n "$SOURCE" ]; then
            # Remove specific source rule from FedoraWorkstation zone
            firewall-cmd --zone=$ZONE --remove-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"$PROTO\" accept"
            echo "Disabled port $PORT/$PROTO for source $SOURCE in zone $ZONE"
        else
            # Disable port for all in FedoraWorkstation zone
            firewall-cmd --zone=$ZONE --remove-port=$PORT/$PROTO
            echo "Disabled port $PORT/$PROTO for all clients in zone $ZONE"
        fi
    fi
else
    echo "Invalid action: $ACTION. Use enable or disable."
    exit 1
fi
EOF

chmod +x /usr/local/bin/service-port

# =========================================================================
# FINALIZATION
# =========================================================================
log_step "Finalizing Configuration..."

# Make sure the firewall is enabled on boot
systemctl enable firewalld

# Final reload to apply all changes
firewall-cmd --reload

echo
echo "✅ Hardening Complete!"
echo "🔥 Default Zone: $(firewall-cmd --get-default-zone)"
echo "🔒 Active Zones:"
firewall-cmd --get-active-zones
echo
echo "💡 Usage Tips:"
echo "- Local services (non-docker) are restricted to localhost access by default in ${FEDORA_ZONE}"
echo "- Docker services are restricted to localhost access by default in ${DOCKER_ZONE}"
echo "- To allow a service port (non-docker): service-port enable PORT PROTOCOL [SOURCE_IP]"
echo "- To allow a docker service port: service-port enable PORT PROTOCOL [SOURCE_IP] docker"
echo "- To disable a service port (non-docker): service-port disable PORT PROTOCOL [SOURCE_IP]"
echo "- To disable a docker service port: service-port disable PORT PROTOCOL [SOURCE_IP] docker"
echo "- Trusted Networks: Edit TRUSTED_NETWORKS in /usr/local/bin/firewall-switcher"
echo "- Port Knocking: Use the sequence ${KNOCK_PORTS[*]} to temporarily open SSH"
echo "- Monitor logs: tail -f /var/log/knockd.log"
echo
echo "🔄 To revert to backup: cp -a ${BACKUP_DIR}/* /etc/firewalld/ && firewall-cmd --reload"

# Example usage to enable port 8000 for a docker container for all network clients
# sudo service-port enable 8000 tcp - docker

# Example usage to enable port 8000 for a docker container for a specific IP only
# sudo service-port enable 8000 tcp 192.168.1.5 docker

# Example usage to disable when done
# sudo service-port disable 8000 tcp - docker