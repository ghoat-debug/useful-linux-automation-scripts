#!/bin/bash
# Docker Firewall Integration Script for Fedora
# This script integrates Docker with your main firewall zones

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "🐳 Integrating Docker with Fedora Firewall Zones"

# Get the current active zone
ACTIVE_ZONE=$(firewall-cmd --get-default-zone)
echo "Current active zone: $ACTIVE_ZONE"

# Option 1: Move Docker interfaces to active zone
echo "Moving Docker interfaces to $ACTIVE_ZONE zone..."

# Get all Docker interfaces
DOCKER_INTERFACES=$(firewall-cmd --zone=docker --list-interfaces 2>/dev/null)

# Move each interface to the active zone
for interface in $DOCKER_INTERFACES; do
    echo "Moving $interface to $ACTIVE_ZONE zone"
    firewall-cmd --zone=docker --remove-interface=$interface
    firewall-cmd --zone=$ACTIVE_ZONE --add-interface=$interface
done

# Save configuration permanently
firewall-cmd --runtime-to-permanent

# Option 2: Create Docker integration service
echo "Setting up Docker integration service..."

# Create the integration script
cat > /usr/local/bin/docker-firewall-integrator <<'EOF'
#!/bin/bash
# Docker Firewall Integration Script
# This script ensures Docker interfaces follow your main zone rules

LOG_FILE="/var/log/docker-firewall.log"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Get current active zone
ACTIVE_ZONE=$(firewall-cmd --get-default-zone)
log_message "Active zone is $ACTIVE_ZONE"

# Check for newly created Docker interfaces
while true; do
    # Get current Docker interfaces from docker zone
    DOCKER_INTERFACES=$(firewall-cmd --zone=docker --list-interfaces 2>/dev/null)
    
    for interface in $DOCKER_INTERFACES; do
        log_message "Found Docker interface $interface in docker zone"
        log_message "Moving $interface to $ACTIVE_ZONE zone"
        
        # Move interface to active zone
        firewall-cmd --zone=docker --remove-interface=$interface
        firewall-cmd --zone=$ACTIVE_ZONE --add-interface=$interface
    done
    
    # Check again after 5 seconds
    sleep 5
done
EOF

chmod +x /usr/local/bin/docker-firewall-integrator

# Create systemd service
cat > /etc/systemd/system/docker-firewall.service <<EOF
[Unit]
Description=Docker Firewall Integration Service
After=firewalld.service docker.service
Requires=firewalld.service docker.service

[Service]
ExecStart=/usr/local/bin/docker-firewall-integrator
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable docker-firewall.service
systemctl start docker-firewall.service

# Option 3: Create a utility to selectively expose Docker services
echo "Creating Docker expose utility..."

cat > /usr/local/bin/docker-expose <<'EOF'
#!/bin/bash
# Docker Service Exposer
# Usage: docker-expose [enable|disable] PORT [SOURCE_IP]

ACTION=$1
PORT=$2
SOURCE=$3
ZONE=$(firewall-cmd --get-default-zone)

if [ -z "$ACTION" ] || [ -z "$PORT" ]; then
    echo "Usage: docker-expose [enable|disable] PORT [SOURCE_IP]"
    echo "Example: docker-expose enable 8080"
    echo "Example: docker-expose enable 8080 192.168.1.5"
    exit 1
fi

if [ "$ACTION" = "enable" ]; then
    if [ -n "$SOURCE" ]; then
        # Enable port only for specific source IP
        firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"tcp\" accept"
        echo "Exposed Docker port $PORT to source $SOURCE in zone $ZONE"
    else
        # Enable port for all clients
        firewall-cmd --zone=$ZONE --add-port=$PORT/tcp
        echo "Exposed Docker port $PORT to all clients in zone $ZONE"
    fi
elif [ "$ACTION" = "disable" ]; then
    if [ -n "$SOURCE" ]; then
        # Remove specific source rule
        firewall-cmd --zone=$ZONE --remove-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"tcp\" accept"
        echo "Disabled Docker port $PORT for source $SOURCE in zone $ZONE"
    else
        # Disable port for all
        firewall-cmd --zone=$ZONE --remove-port=$PORT/tcp
        echo "Disabled Docker port $PORT for all clients in zone $ZONE"
    fi
else
    echo "Invalid action: $ACTION. Use enable or disable."
    exit 1
fi

# Make changes permanent
firewall-cmd --runtime-to-permanent
EOF

chmod +x /usr/local/bin/docker-expose

# Option 4: Update your network switcher to handle Docker interfaces
echo "Updating network switcher to handle Docker interfaces..."

# Modify firewall-switcher script (create backup first)
cp /usr/local/bin/firewall-switcher /usr/local/bin/firewall-switcher.bak

# Add Docker handling to the switcher
cat > /usr/local/bin/firewall-switcher <<'EOF'
#!/bin/bash
# Network Auto-Switching Script for Firewalld
# Automatically switches between firewall zones based on network environment
# Now with Docker integration

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
    
    # Handle Docker interfaces - move them to the new target zone
    DOCKER_INTERFACES=$(firewall-cmd --zone=docker --list-interfaces 2>/dev/null)
    for interface in $DOCKER_INTERFACES; do
        log_message "Moving Docker interface $interface to $TARGET_ZONE zone"
        firewall-cmd --zone=docker --remove-interface=$interface
        firewall-cmd --zone="$TARGET_ZONE" --add-interface=$interface
    done
    
    # Set default zone
    firewall-cmd --set-default-zone=${TARGET_ZONE}
    
    # Notify user if possible
    if command -v notify-send &>/dev/null; then
        notify-send "Firewall Zone Changed" "Switched to $TARGET_ZONE zone ($REASON)"
    fi
else
    log_message "Staying in $CURRENT_ZONE zone ($REASON)"
    
    # Even if we're not switching zones, ensure Docker interfaces are in the correct zone
    DOCKER_INTERFACES=$(firewall-cmd --zone=docker --list-interfaces 2>/dev/null)
    for interface in $DOCKER_INTERFACES; do
        docker_interface_zone=$(firewall-cmd --get-zone-of-interface="$interface" 2>/dev/null)
        if [ "$docker_interface_zone" = "docker" ]; then
            log_message "Moving Docker interface $interface to $CURRENT_ZONE zone"
            firewall-cmd --zone=docker --remove-interface=$interface
            firewall-cmd --zone="$CURRENT_ZONE" --add-interface=$interface
        fi
    done
fi

# Make changes permanent
firewall-cmd --runtime-to-permanent
EOF

chmod +x /usr/local/bin/firewall-switcher

# Apply changes
firewall-cmd --reload

echo "✅ Docker firewall integration complete!"
echo
echo "💡 Usage Tips:"
echo "- Docker interfaces are now integrated with your main zones"
echo "- To expose a Docker service: docker-expose enable PORT [SOURCE_IP]"
echo "- To hide a Docker service: docker-expose disable PORT [SOURCE_IP]"
echo "- Monitor logs: tail -f /var/log/docker-firewall.log"
echo
echo "⚠️ Note: After creating new Docker networks, services may take up to 5 seconds to be protected"