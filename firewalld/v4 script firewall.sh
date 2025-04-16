#!/bin/bash
# Improved Fedora 41 Firewall Hardening Script (firewalld 2.2.3 compatible)
# Security Targets:
# 1. Block all local network access to services unless explicitly allowed
# 2. Allow localhost full access
# 3. Implement proper port knocking for SSH access
# 4. Maintain network auto-switching functionality

# --- Configuration ---
FEDORA_ZONE="FedoraWorkstation"
FORTRESS_ZONE="fortress"
KNOCK_PORTS=(7000 8000 9000)  # Port knocking sequence
SSH_PORT=22

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
# 1. HARDEN DEFAULT ZONE (FedoraWorkstation)
# =========================================================================
log_step "Configuring ${FEDORA_ZONE} zone for localhost-only access by default..."

# Base configuration - set reject target
firewall-cmd --permanent --zone=${FEDORA_ZONE} --set-target=REJECT

# Remove existing port definitions - we'll add them back with restrictions
for port in "${KNOCK_PORTS[@]}"; do
    firewall-cmd --permanent --zone=${FEDORA_ZONE} --remove-port=${port}/tcp 2>/dev/null || true
done

# Make sure we have dhcpv6-client for network connectivity
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-service=dhcpv6-client

# Ensure localhost has full access - this is critical
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-source=127.0.0.1/8
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-source=::1/128

# Add rich rules for localhost access again to be thorough
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv6" source address="::1" accept'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" accept'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv6" source address="::1/128" accept'

# Add port knocking ports but ONLY accessible from outside (not localhost)
# This is important for the knocking mechanism to work
for port in "${KNOCK_PORTS[@]}"; do
    # Allow the port for knocking but limit connection rate
    firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule="rule family=\"ipv4\" port port=\"$port\" protocol=\"tcp\" accept limit value=\"5/m\""
    firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule="rule family=\"ipv6\" port port=\"$port\" protocol=\"tcp\" accept limit value=\"5/m\""
done

# Direct rules for advanced protection
add_direct_rule ipv4 INPUT "-m conntrack --ctstate INVALID -j DROP"
add_direct_rule ipv6 INPUT "-m conntrack --ctstate INVALID -j DROP"
add_direct_rule ipv4 INPUT "! -i lo -s 127.0.0.0/8 -j DROP"
add_direct_rule ipv6 INPUT "! -i lo -s ::1/128 -j DROP"

# SYN Flood protection
add_direct_rule ipv4 INPUT "-p tcp --syn -m limit --limit 15/s -j ACCEPT"
add_direct_rule ipv6 INPUT "-p tcp --syn -m limit --limit 15/s -j ACCEPT"

# Block port scans - enable this if you want aggressive blocking of port scanners
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

# Essential outbound rules 
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

# Allow limited ICMP
add_direct_rule ipv4 INPUT "-p icmp -m limit --limit 5/s -j ACCEPT"
add_direct_rule ipv6 INPUT "-p ipv6-icmp -m limit --limit 5/s -j ACCEPT"

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
                
                # Open the SSH port with timeout
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
TRUSTED_NETWORKS=("HomeLAN" "CorporateVPN")  # Add your trusted network SSIDs here
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
echo "- Local services are now restricted to localhost access by default"
echo "- Trusted Networks: Edit TRUSTED_NETWORKS in /usr/local/bin/firewall-switcher"
echo "- Port Knocking: Use the sequence ${KNOCK_PORTS[*]} to temporarily open SSH"
echo "- Monitor logs: tail -f /var/log/knockd.log"
echo
echo "🔄 To revert to backup: cp -a ${BACKUP_DIR}/* /etc/firewalld/ && firewall-cmd --reload"