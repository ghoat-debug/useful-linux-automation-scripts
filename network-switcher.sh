#!/bin/bash
# Auto Network Profile Switcher for Fedora
# Purpose: Automatically switch to appropriate firewall zone based on network connectivity
# Maintainer: Your Name <your.email@example.com>
# License: MIT
# Version: 1.0

# ANSI color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/firewall-profile-switcher.log"

# Configuration file for trusted networks
CONFIG_FILE="/etc/firewall-trusted-networks.conf"

# Function to display usage
show_usage() {
    echo -e "${BLUE}Auto Network Profile Switcher${NC}"
    echo -e "Automatically manages firewall zones based on connected networks"
    echo
    echo -e "Usage: $0 [OPTION]"
    echo -e "  ${GREEN}--setup${NC}          Create configuration file for trusted networks"
    echo -e "  ${GREEN}--add-trusted${NC}    Add current network to trusted networks"
    echo -e "  ${GREEN}--status${NC}         Show current status and active profile"
    echo -e "  ${GREEN}--daemon${NC}         Run in daemon mode (monitor and switch automatically)"
    echo -e "  ${GREEN}--manual${NC}         Manually select a profile"
    echo -e "  ${GREEN}--help${NC}           Display this help message"
    echo
    echo -e "Example: $0 --add-trusted"
}

# Function for logging
log_message() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "$timestamp - $message" >> "$LOG_FILE"
    echo -e "$message"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Create configuration file for trusted networks
setup_config() {
    check_root
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Configuration file already exists.${NC}"
        echo -e "Do you want to overwrite it? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Operation canceled.${NC}"
            return
        fi
    fi
    
    cat > "$CONFIG_FILE" << EOF
# Trusted Networks Configuration
# Format: SSID|BSSID|NetworkName|Description
# Example: MyHomeWifi|00:11:22:33:44:55|home|My secure home network
# Lines starting with # are ignored

# Add your trusted networks below:
EOF
    
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}Configuration file created at $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Add trusted networks using: $0 --add-trusted${NC}"
}

# Get current network information
get_current_network() {
    # Get primary interface
    local interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    
    if [[ -z "$interface" ]]; then
        echo "DISCONNECTED"
        return
    fi
    
    # Check if wireless
    if [[ "$interface" == wl* ]]; then
        # Get SSID and BSSID
        local iwconfig_output=$(iwconfig "$interface" 2>/dev/null)
        local ssid=$(echo "$iwconfig_output" | grep -o "ESSID:\"[^\"]*\"" | cut -d'"' -f2)
        local bssid=$(echo "$iwconfig_output" | grep -o "Access Point: [0-9A-F:]*" | cut -d' ' -f3)
        
        # If no SSID found, try using iw command
        if [[ -z "$ssid" ]]; then
            ssid=$(iw dev "$interface" info | grep ssid | awk '{print $2}')
            bssid=$(iw dev "$interface" link | grep "Connected to" | awk '{print $3}')
        fi
        
        if [[ -n "$ssid" ]]; then
            echo "WIRELESS|$interface|$ssid|$bssid"
        else
            echo "UNKNOWN_WIRELESS|$interface"
        fi
    else
        # Wired network
        echo "WIRED|$interface"
    fi
}

# Check if current network is trusted
is_trusted_network() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Configuration file not found. Run --setup first.${NC}"
        return 1
    fi
    
    local network_info="$1"
    local IFS='|'
    read -ra network_parts <<< "$network_info"
    
    local network_type="${network_parts[0]}"
    local interface="${network_parts[1]}"
    
    # If disconnected or unknown, not trusted
    if [[ "$network_type" == "DISCONNECTED" || "$network_type" == "UNKNOWN_WIRELESS" ]]; then
        return 1
    fi
    
    # If wireless, check SSID and BSSID
    if [[ "$network_type" == "WIRELESS" ]]; then
        local ssid="${network_parts[2]}"
        local bssid="${network_parts[3]}"
        
        # Check if SSID or BSSID is in trusted networks file
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$line" ]] && continue
            
            IFS='|' read -ra trusted_parts <<< "$line"
            local trusted_ssid="${trusted_parts[0]}"
            local trusted_bssid="${trusted_parts[1]}"
            
            # If SSID or BSSID matches, this is a trusted network
            if [[ "$ssid" == "$trusted_ssid" || "$bssid" == "$trusted_bssid" ]]; then
                return 0
            fi
        done < "$CONFIG_FILE"
    fi
    
    # For wired networks, add custom logic here if needed
    # By default, we'll treat wired networks as untrusted
    
    # Not found in trusted networks
    return 1
}

# Add current network to trusted networks
add_trusted_network() {
    check_root
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Configuration file not found. Creating it now.${NC}"
        setup_config
    fi
    
    local network_info=$(get_current_network)
    local IFS='|'
    read -ra network_parts <<< "$network_info"
    
    local network_type="${network_parts[0]}"
    local interface="${network_parts[1]}"
    
    if [[ "$network_type" == "DISCONNECTED" ]]; then
        echo -e "${RED}Error: Not connected to any network${NC}"
        return 1
    elif [[ "$network_type" == "UNKNOWN_WIRELESS" ]]; then
        echo -e "${RED}Error: Connected to wireless network but could not determine SSID${NC}"
        return 1
    elif [[ "$network_type" == "WIRED" ]]; then
        echo -e "${YELLOW}Warning: Adding wired networks to trusted list is not recommended${NC}"
        echo -e "They can be more easily spoofed. Continue? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Operation canceled.${NC}"
            return
        fi
        
        echo -e "Enter a name for this wired network connection:"
        read -r wired_name
        echo -e "Enter description for this network:"
        read -r description
        
        echo "WIRED|$interface|$wired_name|$description" >> "$CONFIG_FILE"
        echo -e "${GREEN}Added wired network to trusted networks${NC}"
        return 0
    elif [[ "$network_type" == "WIRELESS" ]]; then
        local ssid="${network_parts[2]}"
        local bssid="${network_parts[3]}"
        
        echo -e "Current wireless network:"
        echo -e "  ${BLUE}SSID:${NC} $ssid"
        echo -e "  ${BLUE}BSSID:${NC} $bssid"
        echo -e "  ${BLUE}Interface:${NC} $interface"
        
        echo -e "Enter description for this network:"
        read -r description
        
        echo "$ssid|$bssid|wireless|$description" >> "$CONFIG_FILE"
        echo -e "${GREEN}Added wireless network to trusted networks${NC}"
        return 0
    fi
    
    echo -e "${RED}Error: Unknown network type${NC}"
    return 1
}

# Switch firewall profile based on network trust
switch_profile() {
    local network_info="$1"
    local trust_status="$2"
    local force_profile="$3"
    
    local IFS='|'
    read -ra network_parts <<< "$network_info"
    
    local network_type="${network_parts[0]}"
    local interface="${network_parts[1]}"
    
    # Get current zone for the interface
    local current_zone=$(firewall-cmd --get-zone-of-interface="$interface" 2>/dev/null)
    if [[ -z "$current_zone" ]]; then
        current_zone="(none)"
    fi
    
    # Determine target zone
    local target_zone
    if [[ -n "$force_profile" ]]; then
        target_zone="$force_profile"
    elif [[ "$trust_status" -eq 0 ]]; then
        target_zone="FedoraWorkstation"
    else
        target_zone="zerotrust"
    fi
    
    # Skip if already in the right zone
    if [[ "$current_zone" == "$target_zone" ]]; then
        log_message "${YELLOW}Interface $interface already in $target_zone zone${NC}"
        return
    fi
    
    # Apply the appropriate zone
    if firewall-cmd --zone="$target_zone" --change-interface="$interface" --permanent; then
        firewall-cmd --reload
        
        if [[ "$target_zone" == "zerotrust" ]]; then
            log_message "${RED}⚠️  Switched $interface to ZERO TRUST mode${NC}"
            notify-send -u critical "Zero Trust Firewall Mode" "Network interface $interface is now in restrictive Zero Trust mode for untrusted network" 2>/dev/null || true
        else
            log_message "${GREEN}✓ Switched $interface to standard mode (trusted network)${NC}"
            notify-send "Firewall Mode Change" "Network interface $interface is now in standard mode" 2>/dev/null || true
        fi
    else
        log_message "${RED}Error: Failed to change firewall zone${NC}"
    fi
}

# Show current status
show_status() {
    echo -e "${BLUE}=== Network and Firewall Status ===${NC}"
    
    # Get network information
    local network_info=$(get_current_network)
    local IFS='|'
    read -ra network_parts <<< "$network_info"
    
    local network_type="${network_parts[0]}"
    local interface="${network_parts[1]}"
    
    echo -e "${CYAN}Network Status:${NC}"
    if [[ "$network_type" == "DISCONNECTED" ]]; then
        echo -e "  ${RED}Not connected to any network${NC}"
    elif [[ "$network_type" == "WIRELESS" ]]; then
        local ssid="${network_parts[2]}"
        local bssid="${network_parts[3]}"
        echo -e "  ${GREEN}Connected to wireless network${NC}"
        echo -e "  ${BLUE}SSID:${NC} $ssid"
        echo -e "  ${BLUE}BSSID:${NC} $bssid"
        echo -e "  ${BLUE}Interface:${NC} $interface"
        
        # Check if trusted
        if is_trusted_network "$network_info"; then
            echo -e "  ${GREEN}Network Status: TRUSTED${NC}"
        else
            echo -e "  ${RED}Network Status: UNTRUSTED${NC}"
        fi
    elif [[ "$network_type" == "WIRED" ]]; then
        echo -e "  ${GREEN}Connected to wired network${NC}"
        echo -e "  ${BLUE}Interface:${NC} $interface"
        
        # Check if trusted
        if is_trusted_network "$network_info"; then
            echo -e "  ${GREEN}Network Status: TRUSTED${NC}"
        else
            echo -e "  ${RED}Network Status: UNTRUSTED${NC}"
        fi
    else
        echo -e "  ${YELLOW}Unknown connection state${NC}"
    fi
    
    echo
    echo -e "${CYAN}Firewall Status:${NC}"
    echo -e "  ${BLUE}Firewalld Status:${NC} $(systemctl is-active firewalld)"
    echo -e "  ${BLUE}Default Zone:${NC} $(firewall-cmd --get-default-zone)"
    
    echo
    echo -e "${CYAN}Active Zones:${NC}"
    firewall-cmd --get-active-zones | while read -r zone; do
        if [[ "$zone" == *"(default)"* || "$zone" == *"interfaces:"* ]]; then
            echo -e "  ${GREEN}$zone${NC}"
        else
            echo -e "  ${BLUE}$zone${NC}"
        fi
    done
    
    echo
    echo -e "${CYAN}Recommendation:${NC}"
    if [[ "$network_type" == "DISCONNECTED" ]]; then
        echo -e "  ${YELLOW}No action needed${NC}"
    else
        if is_trusted_network "$network_info"; then
            if [[ $(firewall-cmd --get-zone-of-interface="$interface" 2>/dev/null) == "zerotrust" ]]; then
                echo -e "  ${YELLOW}Current network is trusted but Zero Trust mode is active${NC}"
                echo -e "  Recommended action: ${GREEN}Switch to standard mode${NC}"
                echo -e "  Run: $0 --manual FedoraWorkstation"
            else
                echo -e "  ${GREEN}Current configuration is appropriate for a trusted network${NC}"
            fi
        else
            if [[ $(firewall-cmd --get-zone-of-interface="$interface" 2>/dev/null) != "zerotrust" ]]; then
                echo -e "  ${RED}⚠️  Current network is UNTRUSTED but standard mode is active${NC}"
                echo -e "  Recommended action: ${RED}Switch to Zero Trust mode${NC}"
                echo -e "  Run: $0 --manual zerotrust"
            else
                echo -e "  ${GREEN}Current configuration is appropriate for an untrusted network${NC}"
            fi
        fi
    fi
}

# Manual profile selection
manual_profile_selection() {
    check_root
    
    local profile="$1"
    if [[ -z "$profile" ]]; then
        echo -e "${BLUE}Available profiles:${NC}"
        echo -e "  ${GREEN}1)${NC} FedoraWorkstation (Standard)"
        echo -e "  ${RED}2)${NC} zerotrust (Ultra Secure)"
        echo -e "Enter profile number:"
        read -r selection
        
        case "$selection" in
            1) profile="FedoraWorkstation" ;;
            2) profile="zerotrust" ;;
            *) echo -e "${RED}Invalid selection${NC}"; return 1 ;;
        esac
    fi
    
    # Validate profile
    if ! firewall-cmd --get-zones | grep -w "$profile" >/dev/null; then
        echo -e "${RED}Error: Profile '$profile' does not exist${NC}"
        return 1
    fi
    
    # Get network info
    local network_info=$(get_current_network)
    local IFS='|'
    read -ra network_parts <<< "$network_info"
    
    local network_type="${network_parts[0]}"
    local interface="${network_parts[1]}"
    
    if [[ "$network_type" == "DISCONNECTED" ]]; then
        echo -e "${RED}Error: Not connected to any network${NC}"
        return 1
    fi
    
    # Force profile change
    switch_profile "$network_info" "99" "$profile"
}

# Daemon mode - continuously monitor network and switch profiles
daemon_mode() {
    check_root
    
    log_message "${BLUE}Starting auto network profile switcher daemon...${NC}"
    
    while true; do
        local network_info=$(get_current_network)
        
        if [[ "$(echo "$network_info" | cut -d'|' -f1)" != "DISCONNECTED" ]]; then
            if is_trusted_network "$network_info"; then
                switch_profile "$network_info" 0
            else
                switch_profile "$network_info" 1
            fi
        fi
        
        # Wait before checking again (30 seconds)
        sleep 30
    done
}

# Install as a systemd service
install_service() {
    check_root
    
    # Copy script to system location
    local script_path="/usr/local/bin/network-profile-switcher"
    cp "$0" "$script_path"
    chmod +x "$script_path"
    
    # Create systemd service file
    cat > /etc/systemd/system/network-profile-switcher.service << EOF
[Unit]
Description=Network Profile Switcher Service
After=network.target NetworkManager.service firewalld.service
Wants=network.target NetworkManager.service firewalld.service

[Service]
Type=simple
ExecStart=$script_path --daemon
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable the service
    systemctl daemon-reload
    systemctl enable network-profile-switcher.service
    systemctl start network-profile-switcher.service
    
    echo -e "${GREEN}Service installed and started successfully${NC}"
    echo -e "Check status with: ${CYAN}systemctl status network-profile-switcher${NC}"
}

# Main execution
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# Parse arguments
case "$1" in
    --setup)
        setup_config
        ;;
    --add-trusted)
        add_trusted_network
        ;;
    --status)
        show_status
        ;;
    --daemon)
        daemon_mode
        ;;
    --manual)
        manual_profile_selection "$2"
        ;;
    --install-service)
        install_service
        ;;
    --help)
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_usage
        exit 1
        ;;
esac

exit 0
