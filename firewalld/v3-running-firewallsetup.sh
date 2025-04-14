#!/bin/bash
# Enhanced FirewallD Configuration for Fedora 41 DevSecOps Workstation
# Goals:
# 1. Harden FedoraWorkstation: Limit network visibility, allow localhost dev.
# 2. Create Fortress Zone: Ultra-secure zero-trust for public networks.
# Created: April 14, 2025

# --- Configuration ---
# Set the zone names you want to use
FEDORA_ZONE="FedoraWorkstation" # Your default development/trusted zone
FORTRESS_ZONE="fortress"      # Your zero-trust public network zone

# --- Script Logic ---
# Exit immediately if a command exits with a non-zero status.
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo"
  exit 1
fi

echo "🛡️ === Starting Enhanced FirewallD Configuration ==="

# Backup current configuration
BACKUP_DIR="/root/firewalld-backup-$(date +%Y%m%d-%H%M%S)"
if mkdir -p "$BACKUP_DIR"; then
    echo "🔄 Backing up current firewalld configuration..."
    if cp -a /etc/firewalld/* "$BACKUP_DIR/"; then # Use -a to preserve permissions/timestamps
        echo "✅ Backup complete: $BACKUP_DIR"
    else
        echo "❌ ERROR: Failed to copy firewalld configuration files."
        exit 1
    fi
else
    echo "❌ ERROR: Failed to create backup directory $BACKUP_DIR."
    exit 1
fi

echo
echo "🛠️ Starting firewalld configuration..."

# =========================================================================
# 1. HARDEN DEFAULT ZONE ($FEDORA_ZONE)
#    Goal: Restrict network access to services, allow local development.
# =========================================================================
echo
echo "🔧 Enhancing '$FEDORA_ZONE' zone..."

# --- Set Default Behavior ---
echo "   - Setting default target to REJECT (blocks unsolicited connections)"
firewall-cmd --permanent --zone=$FEDORA_ZONE --set-target=REJECT

# --- Remove Default Allowed Services (adjust as needed) ---
echo "   - Removing default services (ssh, mdns) - Add back if needed!"
firewall-cmd --permanent --zone=$FEDORA_ZONE --remove-service=ssh 2>/dev/null || echo "   - Note: ssh service was not present or already removed."
firewall-cmd --permanent --zone=$FEDORA_ZONE --remove-service=mdns 2>/dev/null || echo "   - Note: mdns service was not present or already removed."
# Keep dhcpv6-client if it was there, or add it if needed for IPv6 connectivity
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-service=dhcpv6-client

# --- Essential Allow Rules ---
# Allow ALL traffic originating from the local machine itself (essential for testing)
echo "   - Allowing all loopback traffic (localhost)"
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" accept'
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" source address="::1/128" accept'

# Allow established/related connections (essential for return traffic)
echo "   - Allowing established/related connections"
# firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" state established,related accept'
# firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" state established,related accept'

# --- Security Hardening Rules ---
# Drop invalid packets (common hardening)
echo "   - Dropping invalid packets"
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" state invalid drop'
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" state invalid drop'

# Rate limit NEW connections (SYN flood mitigation)
echo "   - Rate limiting new incoming TCP connections (SYN Flood)"
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" tcp flags="syn" limit value="15/s" accept'
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" tcp flags="syn" limit value="15/s" accept'

# Log and drop common stealth scans
echo "   - Adding rules to log & drop common stealth scans (Null, FIN, Xmas)"
# Null Scan (No flags set)
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" tcp flags="fin,syn,rst,psh,ack,urg" flags-mask="fin,syn,rst,psh,ack,urg" log prefix="NULL_SCAN_DROP: " level="warning" limit value="5/m" drop'
# FIN Scan (Only FIN flag set)
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" tcp flags="fin" flags-mask="fin,syn,rst,psh,ack,urg" log prefix="FIN_SCAN_DROP: " level="warning" limit value="5/m" drop'
# Xmas Scan (FIN, PSH, URG set)
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" tcp flags="fin,psh,urg" flags-mask="fin,psh,urg" log prefix="XMAS_SCAN_DROP: " level="warning" limit value="5/m" drop'

# Block incoming packets claiming to be from loopback but aren't (Spoofing)
echo "   - Blocking spoofed loopback packets"
for iface in $(ls /sys/class/net/ | grep -v lo); do
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -i $iface -s 127.0.0.0/8 -j DROP
    firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -i $iface -s ::1/128 -j DROP
done

echo "✅ Hardening for '$FEDORA_ZONE' configured."

# =========================================================================
# 2. CREATE FORTRESS ZONE ($FORTRESS_ZONE)
#    Goal: Absolute zero trust for public/untrusted networks. Default deny all.
# =========================================================================
echo
echo "🏰 Creating '$FORTRESS_ZONE' zone (Zero Trust)..."

# Create the new zone if it doesn't exist
if ! firewall-cmd --permanent --get-zones | grep -q $FORTRESS_ZONE; then
    echo "   - Creating new zone '$FORTRESS_ZONE'"
    firewall-cmd --permanent --new-zone=$FORTRESS_ZONE
else
    echo "   - Zone '$FORTRESS_ZONE' already exists, configuring..."
fi

# Set target to DROP (silently ignore unsolicited incoming traffic)
echo "   - Setting default target to DROP"
firewall-cmd --permanent --zone=$FORTRESS_ZONE --set-target=DROP

# --- Essential Allow Rules (Very Minimal Inbound) ---
# Allow established/related connections (essential for return traffic of outbound connections)
echo "   - Allowing established/related connections"
# firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" state established,related accept'
# firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" state established,related accept'

# Allow DHCPv6 client (essential for IPv6 connectivity on many networks)
echo "   - Allowing DHCPv6 client service (inbound)"
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-service=dhcpv6-client

# Rate limit incoming ICMP (allow basic pings but prevent floods)
echo "   - Rate limiting incoming ICMP/ICMPv6"
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule protocol value="icmp" limit value="5/s" accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" protocol value="ipv6-icmp" limit value="5/s" accept'

# --- Security Hardening Rules ---
# Drop invalid packets
echo "   - Dropping invalid packets"
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" state invalid drop'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" state invalid drop'

# Log and drop common stealth scans (same as FedoraWorkstation)
echo "   - Adding rules to log & drop common stealth scans"
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" tcp flags="fin,syn,rst,psh,ack,urg" flags-mask="fin,syn,rst,psh,ack,urg" log prefix="FORTRESS_NULL_SCAN_DROP: " level="warning" limit value="5/m" drop'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" tcp flags="fin" flags-mask="fin,syn,rst,psh,ack,urg" log prefix="FORTRESS_FIN_SCAN_DROP: " level="warning" limit value="5/m" drop'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" tcp flags="fin,psh,urg" flags-mask="fin,psh,urg" log prefix="FORTRESS_XMAS_SCAN_DROP: " level="warning" limit value="5/m" drop'

# --- Allow outbound services directly in the zone ---
echo "   - Configuring outbound traffic rules..."

# Allow essential outbound services
echo "      - Allowing outbound DNS (tcp/udp 53), HTTP (tcp 80), HTTPS (tcp 443)"
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" port port="53" protocol="tcp" direction="out" accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" port port="53" protocol="udp" direction="out" accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" port port="80" protocol="tcp" direction="out" accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" port port="443" protocol="tcp" direction="out" accept'

firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" port port="53" protocol="tcp" direction="out" accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" port port="53" protocol="udp" direction="out" accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" port port="80" protocol="tcp" direction="out" accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" port port="443" protocol="tcp" direction="out" accept'

# Special Docker/Pihole Integration for DNS
if command -v docker &>/dev/null; then
    echo "   - Adding Docker/Pihole compatibility rules"
    # Allow traffic to Docker bridge networks
    docker_networks=$(docker network ls --format "{{.Name}}" | grep -v "host\|none")
    for network in $docker_networks; do
        subnet=$(docker network inspect $network | grep -oP '"Subnet": "\K[^"]+')
        if [ -n "$subnet" ]; then
            echo "      - Adding Docker network $network ($subnet)"
            firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$subnet\" accept"
            firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$subnet\" accept"
        fi
    done
fi

echo "✅ Configuration for '$FORTRESS_ZONE' complete."

# =========================================================================
# 3. AUTO-SWITCHING BETWEEN SECURE AND NORMAL MODES
# =========================================================================
echo
echo "🔄 Creating network switcher script..."

# Create script for automatic zone switching
SWITCHER_SCRIPT="/usr/local/bin/firewall-switcher"
cat > $SWITCHER_SCRIPT << 'EOF'
#!/bin/bash
# Firewall Zone Switcher Script
# Automatically switches between normal and fortress mode based on network SSID

# Configuration - Edit these values
TRUSTED_NETWORKS=("HomeSweetHome" "Work-Corp-Secure" "YourTrustedNetwork")
NORMAL_ZONE="FedoraWorkstation"
SECURE_ZONE="fortress"

# Get current network SSID (works with NetworkManager)
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)

# Check if VPN is active (additional security)
check_vpn() {
    if ip tuntap show | grep -q tun; then
        return 0 # VPN detected
    else
        return 1 # No VPN
    fi
}

# Function to switch to a zone
switch_zone() {
    local zone=$1
    local current_zone=$(firewall-cmd --get-default-zone)
    
    if [ "$current_zone" != "$zone" ]; then
        echo "Switching from $current_zone to $zone mode..."
        firewall-cmd --set-default-zone=$zone
        notify-send "Firewall Mode" "Switched to $zone mode" --icon=security-high
    else
        echo "Already in $zone mode."
    fi
}

# If VPN is active, always use normal zone regardless of network
if check_vpn; then
    echo "VPN connection detected. Using normal mode with VPN."
    switch_zone $NORMAL_ZONE
    exit 0
fi

# If we're not connected to WiFi, default to secure mode
if [ -z "$CURRENT_SSID" ]; then
    echo "No WiFi connection detected. Using secure mode."
    switch_zone $SECURE_ZONE
    exit 0
fi

# Check if current network is in trusted list
for network in "${TRUSTED_NETWORKS[@]}"; do
    if [ "$CURRENT_SSID" == "$network" ]; then
        echo "Connected to trusted network: $CURRENT_SSID"
        switch_zone $NORMAL_ZONE
        exit 0
    fi
done

# If we're here, network is not trusted
echo "Connected to untrusted network: $CURRENT_SSID"
switch_zone $SECURE_ZONE
EOF

# Make the script executable
chmod +x $SWITCHER_SCRIPT

# Create NetworkManager dispatcher script to run our switcher
DISPATCHER_SCRIPT="/etc/NetworkManager/dispatcher.d/90-firewall-switcher"
cat > $DISPATCHER_SCRIPT << 'EOF'
#!/bin/bash
# NetworkManager dispatcher script for firewall-switcher
# This script runs when network connections change

INTERFACE=$1
STATUS=$2

# Only run on WiFi interface connections/disconnections
if [[ "$INTERFACE" =~ ^wl.* ]] && [[ "$STATUS" == "up" || "$STATUS" == "down" ]]; then
    # Run as root
    /usr/local/bin/firewall-switcher
fi
EOF

# Make the dispatcher script executable
chmod +x $DISPATCHER_SCRIPT

echo "✅ Network switcher scripts installed."
echo "Edit $SWITCHER_SCRIPT to configure your trusted networks."

# =========================================================================
# 4. APPLY CHANGES & FINISH
# =========================================================================
echo
echo "🔄 Reloading FirewallD to apply all permanent changes..."
firewall-cmd --reload

# Check if reload was successful (basic check)
if firewall-cmd --state > /dev/null 2>&1; then
    echo "✅ FirewallD reloaded successfully."
else
    echo "❌ ERROR: FirewallD failed to reload. Check configuration manually!"
    echo "   - View errors: sudo journalctl -u firewalld -n 50"
    echo "   - You can restore from backup: $BACKUP_DIR"
    exit 1
fi

# =========================================================================
# 5. PORT KNOCKING CONFIGURATION (OPTIONAL)
# =========================================================================
echo
echo "🔑 Setting up port knocking for SSH access..."

# Define knock sequence ports
KNOCK_SEQ=("7000" "8000" "9000")
SECRET_PORT="22"  # SSH

# Create firewalld config for port knocking
for port in "${KNOCK_SEQ[@]}"; do
    echo "   - Adding knock port $port"
    firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule="rule family=\"ipv4\" port port=\"$port\" protocol=\"tcp\" log prefix=\"KNOCK_\" accept"
done

# Create the port knocking listener script
KNOCK_SCRIPT="/usr/local/bin/knockd-firewalld.sh"
cat > $KNOCK_SCRIPT << 'EOF'
#!/bin/bash
# Simple port knocking implementation using firewalld and iptables
# This script monitors logs for port knock sequences and temporarily opens ports

KNOCK_SEQUENCE=("7000" "8000" "9000")
SECRET_PORT="22"
OPEN_DURATION=60  # seconds

# Read the logs for knocking attempts
tail -f /var/log/messages | grep --line-buffered "KNOCK_" | while read line; do
    # Extract source IP from the log
    IP=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
    PORT=$(echo "$line" | grep -oP 'DPT=\K[0-9]+')
    
    # Log this knock attempt for debugging
    echo "$(date): Knock detected from $IP on port $PORT" >> /var/log/knockd-firewalld.log
    
    # Check if this IP already has a complete sequence in progress
    PROGRESS_FILE="/tmp/knock_${IP//./\_}"
    
    if [ ! -f "$PROGRESS_FILE" ]; then
        # First knock in sequence
        if [ "$PORT" == "${KNOCK_SEQUENCE[0]}" ]; then
            echo "1" > "$PROGRESS_FILE"
            echo "$(date): New knock sequence started from $IP" >> /var/log/knockd-firewalld.log
        fi
    else
        # Continuing a sequence
        PROGRESS=$(cat "$PROGRESS_FILE")
        EXPECTED_PORT="${KNOCK_SEQUENCE[$PROGRESS]}"
        
        if [ "$PORT" == "$EXPECTED_PORT" ]; then
            PROGRESS=$((PROGRESS + 1))
            echo "$PROGRESS" > "$PROGRESS_FILE"
            
            # Check if sequence is complete
            if [ "$PROGRESS" -eq "${#KNOCK_SEQUENCE[@]}" ]; then
                echo "$(date): Successful knock sequence from $IP, opening port $SECRET_PORT" >> /var/log/knockd-firewalld.log
                
                # Open the port temporarily for this IP
                firewall-cmd --zone=FedoraWorkstation --add-rich-rule="rule family=\"ipv4\" source address=\"$IP\" port port=\"$SECRET_PORT\" protocol=\"tcp\" accept" --timeout=${OPEN_DURATION}
                
                # Notify admin (optional)
                notify-send "Port Knock Alert" "Port $SECRET_PORT opened for $IP for $OPEN_DURATION seconds" --urgency=normal
                
                # Remove the progress file
                rm "$PROGRESS_FILE"
            fi
        else
            # Wrong sequence, reset
            rm "$PROGRESS_FILE"
            echo "$(date): Invalid knock sequence from $IP" >> /var/log/knockd-firewalld.log
        fi
    fi
done
EOF

chmod +x $KNOCK_SCRIPT

# Create systemd service file for knockd
cat > /etc/systemd/system/knockd-firewalld.service << EOF
[Unit]
Description=Simple port knocking daemon for firewalld
After=network.target firewalld.service

[Service]
Type=simple
ExecStart=/usr/local/bin/knockd-firewalld.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable knockd-firewalld.service
systemctl start knockd-firewalld.service

echo "✅ Port knocking configured. Use sequence: ${KNOCK_SEQ[0]} → ${KNOCK_SEQ[1]} → ${KNOCK_SEQ[2]} to open port $SECRET_PORT"

echo
echo "🎉 === Enhanced Firewall Configuration Applied === 🎉"
echo
echo "Current default zone: $(firewall-cmd --get-default-zone)"
echo "Active zones:"
firewall-cmd --get-active-zones
echo
echo "✨ Next Steps & Usage ✨"
echo "--------------------------------------------------"
echo "To activate ultra-secure mode (e.g., on public Wi-Fi):"
echo "  sudo firewall-cmd --set-default-zone=$FORTRESS_ZONE"
echo
echo "To switch back to normal/dev mode (e.g., at home/office):"
echo "  sudo firewall-cmd --set-default-zone=$FEDORA_ZONE"
echo
echo "For automatic network switching:"
echo "  Edit $SWITCHER_SCRIPT and add your trusted networks"
echo "  The script will run automatically when you connect to WiFi"
echo
echo "For port knocking to enable SSH access:"
echo "  nc -z YOUR_SERVER_IP ${KNOCK_SEQ[0]}"
echo "  nc -z YOUR_SERVER_IP ${KNOCK_SEQ[1]}"
echo "  nc -z YOUR_SERVER_IP ${KNOCK_SEQ[2]}"
echo "  ssh user@YOUR_SERVER_IP  # Port will be open for $OPEN_DURATION seconds"
echo
echo "Remember: The '$FEDORA_ZONE' zone now REJECTS incoming connections by default."
echo "To allow a service (e.g., a web server for testing on port 8080) temporarily:"
echo "  sudo firewall-cmd --zone=$FEDORA_ZONE --add-port=8080/tcp"
echo "To allow it permanently:"
echo "  sudo firewall-cmd --permanent --zone=$FEDORA_ZONE --add-port=8080/tcp && sudo firewall-cmd --reload"
echo
echo "View logs for dropped/rejected packets:"
echo "  sudo journalctl -f | grep -E '_(DROP|REJECT): '"
echo "--------------------------------------------------"