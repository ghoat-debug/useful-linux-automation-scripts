 cat /usr/local/bin/firewall-switcher
#!/bin/bash
# Network Auto-Switching Script for Firewalld
# Automatically switches between firewall zones based on network environment

# Configuration
TRUSTED_NETWORKS=("Innovus Office" "Wifi" "coast-white" "WIFI SECURE")  # Add your trusted network SSIDs here
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
