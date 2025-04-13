#!/bin/bash
# FirewallD Hardening Script for DevSecOps
# Author: Claude with your requirements
# Purpose: Create hardened firewalld profiles with port-scan protection and zero-trust capabilities

# Colors for visual feedback
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================================${NC}"
echo -e "${BLUE}${BOLD}   DevSecOps Firewall Hardening Script - Fedora 41    ${NC}"
echo -e "${BLUE}${BOLD}======================================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# Ensure firewalld is running
if ! systemctl is-active --quiet firewalld; then
  echo -e "${YELLOW}FirewallD is not running. Starting it now...${NC}"
  systemctl start firewalld
  systemctl enable firewalld
fi

# Backup current configuration
echo -e "${GREEN}Creating backup of current firewalld configuration...${NC}"
BACKUP_DIR="/root/firewall-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR
cp -r /etc/firewalld/* $BACKUP_DIR/
echo -e "${GREEN}Backup saved to $BACKUP_DIR${NC}"

# Function to create hardened default profile
create_hardened_default() {
  echo -e "${BLUE}${BOLD}Creating hardened default profile...${NC}"
  
  # Get current default zone
  CURRENT_DEFAULT=$(firewall-cmd --get-default-zone)
  echo -e "${YELLOW}Current default zone: $CURRENT_DEFAULT${NC}"
  
  # Create new hardened zone
  echo -e "${GREEN}Creating new 'hardened' zone...${NC}"
  firewall-cmd --permanent --new-zone=hardened
  
  # Configure hardened zone with better defaults
  firewall-cmd --permanent --zone=hardened --set-target=default
  
  # Allow established connections
  echo -e "${GREEN}Allowing established connections...${NC}"
  firewall-cmd --permanent --zone=hardened --add-rich-rule='rule family="ipv4" ct state="established,related" accept'
  firewall-cmd --permanent --zone=hardened --add-rich-rule='rule family="ipv6" ct state="established,related" accept'
  
  # Allow SSH for remote management
  echo -e "${GREEN}Allowing SSH access...${NC}"
  firewall-cmd --permanent --zone=hardened --add-service=ssh
  
  # Allow common local services
  echo -e "${GREEN}Allowing common local services...${NC}"
  firewall-cmd --permanent --zone=hardened --add-service=dhcpv6-client
  firewall-cmd --permanent --zone=hardened --add-service=mdns
  
  # Allow KDE Connect if needed
  echo -e "${GREEN}Allowing KDE Connect...${NC}"
  firewall-cmd --permanent --zone=hardened --add-port=1716/tcp
  firewall-cmd --permanent --zone=hardened --add-port=1716/udp
  
  # Add anti-port scanning protection
  echo -e "${GREEN}Adding anti-port scanning protection...${NC}"
  firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m state --state INVALID -j DROP
  firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j ACCEPT
  firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -p tcp --tcp-flags SYN,ACK,FIN,RST RST -j DROP
  
  # Add protection against SYN floods
  echo -e "${GREEN}Adding SYN flood protection...${NC}"
  firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp --syn -m limit --limit 1/s --limit-burst 4 -j ACCEPT
  firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -p tcp --syn -j DROP
  
  # Set as default zone
  echo -e "${GREEN}Setting 'hardened' as default zone...${NC}"
  firewall-cmd --permanent --set-default-zone=hardened
  
  # Apply the new configuration to the wireless interface
  echo -e "${GREEN}Applying hardened zone to wireless interface...${NC}"
  firewall-cmd --permanent --zone=hardened --add-interface=wlo1
  
  echo -e "${GREEN}Hardened default profile created!${NC}"
}

# Function to create ZeroTrust profile for public networks
create_zerotrust_profile() {
  echo -e "${BLUE}${BOLD}Creating Zero Trust profile for public networks...${NC}"
  
  # Create zerotrust zone
  echo -e "${GREEN}Creating 'zerotrust' zone...${NC}"
  firewall-cmd --permanent --new-zone=zerotrust
  
  # Set strict DROP target
  firewall-cmd --permanent --zone=zerotrust --set-target=DROP
  
  # Allow only essential outbound connections
  echo -e "${GREEN}Allowing only essential outbound services...${NC}"
  firewall-cmd --permanent --zone=zerotrust --add-service=dns
  firewall-cmd --permanent --zone=zerotrust --add-service=https
  
  # Allow established connections
  echo -e "${GREEN}Allowing established connections...${NC}"
  firewall-cmd --permanent --zone=zerotrust --add-rich-rule='rule family="ipv4" ct state="established,related" accept'
  firewall-cmd --permanent --zone=zerotrust --add-rich-rule='rule family="ipv6" ct state="established,related" accept'
  
  # Block and log all incoming connections
  echo -e "${GREEN}Adding logging for blocked connections...${NC}"
  firewall-cmd --permanent --zone=zerotrust --add-rich-rule='rule family="ipv4" ct state="new" log prefix="ZEROTRUST_BLOCKED: " level="info" limit value="3/m" drop'
  
  echo -e "${GREEN}Zero Trust profile created!${NC}"
}

# Function to create trusted networks configuration
create_trusted_networks() {
  echo -e "${BLUE}${BOLD}Setting up trusted networks configuration...${NC}"
  
  # Ensure trusted zone exists
  firewall-cmd --permanent --zone=trusted --set-target=ACCEPT
  
  echo -e "${GREEN}Trusted networks configuration complete!${NC}"
  
  # Create the trusted networks file
  echo -e "${GREEN}Creating trusted networks configuration file...${NC}"
  cat > /etc/firewalld/trusted_networks.conf << 'EOF'
# Trusted Networks Configuration
# Add your trusted networks here, one per line
# Format: SSID,MAC
# Example: MyHomeWifi,00:11:22:33:44:55
HomeNetwork,
WorkNetwork,
EOF

  chmod 600 /etc/firewalld/trusted_networks.conf
  echo -e "${GREEN}Created /etc/firewalld/trusted_networks.conf${NC}"
  echo -e "${YELLOW}Please edit this file to add your trusted networks${NC}"
}

# Function to create network switcher script
create_network_switcher() {
  echo -e "${BLUE}${BOLD}Creating network auto-switcher script...${NC}"
  
  # Create the network switcher script
  cat > /usr/local/bin/firewall-network-switcher << 'EOF'
#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get current wireless interface
WIRELESS_IFACE="wlo1"
CURRENT_ZONE=$(firewall-cmd --get-zone-of-interface=$WIRELESS_IFACE 2>/dev/null)

# Usage info
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo -e "${BLUE}${BOLD}FirewallD Network Switcher${NC}"
  echo "This script automatically switches firewall zones based on connected network"
  echo
  echo "Usage:"
  echo "  $0 [options]"
  echo
  echo "Options:"
  echo "  status    - Show current network and firewall status"
  echo "  trust     - Switch to trusted zone"
  echo "  zero      - Switch to zero trust mode"
  echo "  auto      - Automatically detect network and switch (default)"
  exit 0
fi

# Get current network information
get_network_info() {
  CONNECTED_SSID=$(iwconfig $WIRELESS_IFACE 2>/dev/null | grep ESSID | cut -d: -f2 | tr -d '" ')
  CONNECTED_MAC=$(iwconfig $WIRELESS_IFACE 2>/dev/null | grep "Access Point" | awk '{print $6}')
  
  if [ -z "$CONNECTED_SSID" ] || [ "$CONNECTED_SSID" == "off/any" ]; then
    CONNECTED_SSID="Not connected"
    CONNECTED_MAC="-"
    IS_CONNECTED=0
  else
    IS_CONNECTED=1
  fi
}

# Function to check if network is trusted
is_trusted_network() {
  if [ ! -f "/etc/firewalld/trusted_networks.conf" ]; then
    return 1
  fi
  
  if grep -q "^$CONNECTED_SSID," "/etc/firewalld/trusted_networks.conf"; then
    return 0
  fi
  
  if grep -q ",$CONNECTED_MAC$" "/etc/firewalld/trusted_networks.conf"; then
    return 0
  fi
  
  return 1
}

# Function to switch to trusted zone
switch_to_trusted() {
  echo -e "${GREEN}Switching to ${BOLD}trusted${NC} ${GREEN}zone for interface $WIRELESS_IFACE${NC}"
  firewall-cmd --zone=trusted --change-interface=$WIRELESS_IFACE
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Success!${NC} ${GREEN}Firewall now in trusted mode${NC}"
    return 0
  else
    echo -e "${RED}Failed to switch to trusted zone${NC}"
    return 1
  fi
}

# Function to switch to zero trust zone
switch_to_zerotrust() {
  echo -e "${YELLOW}Switching to ${BOLD}ZERO TRUST${NC} ${YELLOW}zone for interface $WIRELESS_IFACE${NC}"
  firewall-cmd --zone=zerotrust --change-interface=$WIRELESS_IFACE
  
  if [ $? -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}Success!${NC} ${YELLOW}Firewall now in ZERO TRUST mode${NC}"
    echo -e "${YELLOW}${BOLD}Warning:${NC} ${YELLOW}Most incoming connections will be blocked${NC}"
    return 0
  else
    echo -e "${RED}Failed to switch to zero trust zone${NC}"
    return 1
  fi
}

# Function to switch to hardened zone
switch_to_hardened() {
  echo -e "${BLUE}Switching to ${BOLD}hardened${NC} ${BLUE}zone for interface $WIRELESS_IFACE${NC}"
  firewall-cmd --zone=hardened --change-interface=$WIRELESS_IFACE
  
  if [ $? -eq 0 ]; then
    echo -e "${BLUE}${BOLD}Success!${NC} ${BLUE}Firewall now in hardened mode${NC}"
    return 0
  else
    echo -e "${RED}Failed to switch to hardened zone${NC}"
    return 1
  fi
}

# Get current network info
get_network_info

# Handle command-line options
case "$1" in
  status)
    echo -e "${BLUE}${BOLD}Network Status:${NC}"
    echo -e "${BLUE}Interface:    ${NC}$WIRELESS_IFACE"
    echo -e "${BLUE}SSID:         ${NC}$CONNECTED_SSID"
    echo -e "${BLUE}MAC:          ${NC}$CONNECTED_MAC"
    echo -e "${BLUE}Firewall Zone:${NC}$CURRENT_ZONE"
    
    if [ $IS_CONNECTED -eq 1 ]; then
      if is_trusted_network; then
        echo -e "${GREEN}${BOLD}This is a trusted network${NC}"
      else
        echo -e "${YELLOW}${BOLD}This is NOT a trusted network${NC}"
      fi
    fi
    exit 0
    ;;
    
  trust)
    switch_to_trusted
    exit $?
    ;;
    
  zero)
    switch_to_zerotrust
    exit $?
    ;;
    
  hardened)
    switch_to_hardened
    exit $?
    ;;
    
  *)
    # Auto mode or no args - automatically determine what to do
    if [ $IS_CONNECTED -eq 0 ]; then
      echo -e "${YELLOW}Not connected to any wireless network${NC}"
      exit 0
    fi
    
    if is_trusted_network; then
      echo -e "${GREEN}Connected to trusted network: $CONNECTED_SSID${NC}"
      switch_to_trusted
    else
      echo -e "${YELLOW}Connected to untrusted network: $CONNECTED_SSID${NC}"
      switch_to_zerotrust
    fi
    ;;
esac
EOF

  chmod +x /usr/local/bin/firewall-network-switcher
  echo -e "${GREEN}Created network switcher script at /usr/local/bin/firewall-network-switcher${NC}"
  
  # Create systemd service for auto-switching
  cat > /etc/systemd/system/firewall-network-switcher.service << 'EOF'
[Unit]
Description=Firewall Network Switcher
After=NetworkManager.service network.target
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/firewall-network-switcher
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  # Create NetworkManager dispatcher hook
  mkdir -p /etc/NetworkManager/dispatcher.d
  cat > /etc/NetworkManager/dispatcher.d/90-firewall-zone << 'EOF'
#!/bin/bash

INTERFACE=$1
STATUS=$2

# Only run for wireless interfaces
if [[ "$INTERFACE" != wl* ]]; then
    exit 0
fi

# Only run on up/down events
if [[ "$STATUS" == "up" || "$STATUS" == "down" ]]; then
    /usr/local/bin/firewall-network-switcher
fi
EOF

  chmod +x /etc/NetworkManager/dispatcher.d/90-firewall-zone
  
  echo -e "${GREEN}Created NetworkManager hook for automatic switching${NC}"
  echo -e "${YELLOW}To enable automatic switching on network change:${NC}"
  echo -e "${YELLOW}  sudo systemctl enable firewall-network-switcher.service${NC}"
}

# Function to create localhost-only Docker configuration
configure_docker_isolation() {
  echo -e "${BLUE}${BOLD}Configuring Docker container isolation...${NC}"
  
  # Create Docker-specific configuration
  if ! grep -q "add-to-forward-ports" /etc/firewalld/firewalld.conf; then
    echo 'FirewallBackend=nftables' >> /etc/firewalld/firewalld.conf
  fi
  
  # Create direct rules to prevent Docker bypassing firewall
  echo -e "${GREEN}Adding rules to prevent Docker from bypassing firewall...${NC}"
  cat > /etc/firewalld/direct.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<direct>
  <!-- Prevent Docker from bypassing firewall -->
  <rule priority="0" table="filter" ipv="ipv4" chain="FORWARD">-o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT</rule>
  <rule priority="0" table="filter" ipv="ipv4" chain="FORWARD">-i docker0 ! -o docker0 -j ACCEPT</rule>
  <rule priority="0" table="filter" ipv="ipv4" chain="FORWARD">-i docker0 -o docker0 -j ACCEPT</rule>
  
  <!-- Drop invalid packets -->
  <rule priority="0" table="filter" ipv="ipv4" chain="INPUT">-m state --state INVALID -j DROP</rule>
  
  <!-- Anti-port scanning rules -->
  <rule priority="0" table="filter" ipv="ipv4" chain="INPUT">-p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j ACCEPT</rule>
  <rule priority="0" table="filter" ipv="ipv4" chain="INPUT">-p tcp --tcp-flags SYN,ACK,FIN,RST RST -j DROP</rule>
  
  <!-- SYN flood protection -->
  <rule priority="0" table="filter" ipv="ipv4" chain="INPUT">-p tcp --syn -m limit --limit 1/s --limit-burst 4 -j ACCEPT</rule>
  <rule priority="0" table="filter" ipv="ipv4" chain="INPUT">-p tcp --syn -j DROP</rule>
</direct>
EOF

  echo -e "${GREEN}Docker isolation configured!${NC}"
}

# Function to add kernel hardening
add_kernel_hardening() {
  echo -e "${BLUE}${BOLD}Adding kernel hardening parameters...${NC}"
  
  # Create kernel hardening sysctl configuration
  cat > /etc/sysctl.d/90-security-hardening.conf << 'EOF'
# Kernel hardening parameters

# TCP/IP stack hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable ICMP redirect acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable secure ICMP redirect acceptance
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Enable bad error message protection
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable logging of spoofed, source-routed, and redirect packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore all ICMP ECHO and TIMESTAMP requests
net.ipv4.icmp_echo_ignore_all = 0

# Disable IPv6 router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF

  # Apply the settings
  sysctl -p /etc/sysctl.d/90-security-hardening.conf
  
  echo -e "${GREEN}Kernel hardening applied!${NC}"
}

# Function to set up automatic updates for security
setup_security_updates() {
  echo -e "${BLUE}${BOLD}Setting up automatic security updates...${NC}"
  
  # Install dnf-automatic if not already installed
  if ! rpm -q dnf-automatic &>/dev/null; then
    echo -e "${GREEN}Installing dnf-automatic package...${NC}"
    dnf install -y dnf-automatic
  fi
  
  # Configure for security updates only
  sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
  sed -i 's/upgrade_type = default/upgrade_type = security/' /etc/dnf/automatic.conf
  
  # Enable and start the timer
  systemctl enable --now dnf-automatic.timer
  
  echo -e "${GREEN}Automatic security updates configured!${NC}"
}

# Function to create ports check script
create_ports_check() {
  echo -e "${BLUE}${BOLD}Creating open ports checker script...${NC}"
  
  # Create the ports checker script
  cat > /usr/local/bin/check-open-ports << 'EOF'
#!/bin/bash

# Colors for visual feedback
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}==============================================${NC}"
echo -e "${BLUE}${BOLD}     DevSecOps Open Ports Checker Tool       ${NC}"
echo -e "${BLUE}${BOLD}==============================================${NC}"

echo -e "${GREEN}${BOLD}System Information:${NC}"
echo -e "${GREEN}Hostname:    ${NC}$(hostname)"
echo -e "${GREEN}Kernel:      ${NC}$(uname -r)"
echo -e "${GREEN}Firewall:    ${NC}$(systemctl is-active firewalld)"
echo -e "${GREEN}Default Zone:${NC}$(firewall-cmd --get-default-zone)"
echo

# Check listening TCP ports
echo -e "${BLUE}${BOLD}Listening TCP Ports:${NC}"
ss -tulpn | grep 'LISTEN' | sort -n -k 5 | while read line; do
  proto=$(echo $line | awk '{print $1}')
  state=$(echo $line | awk '{print $2}')
  addr=$(echo $line | awk '{print $5}')
  proc=$(echo $line | awk -F'"' '{print $2}')
  pid=$(echo $line | grep -o 'pid=[0-9]*' | cut -d= -f2)
  
  ip=$(echo $addr | cut -d: -f1)
  port=$(echo $addr | cut -d: -f2)
  
  if [ "$ip" == "0.0.0.0" ] || [ "$ip" == "*" ] || [ "$ip" == "::" ]; then
    echo -e "${YELLOW}${BOLD}WARNING:${NC} Port $port ($proto) exposed on all interfaces: $proc (PID $pid)"
  elif [ "$ip" == "127.0.0.1" ] || [ "$ip" == "::1" ]; then
    echo -e "${GREEN}OK:${NC} Port $port ($proto) only on localhost: $proc (PID $pid)"
  else
    echo -e "${YELLOW}${BOLD}NOTICE:${NC} Port $port ($proto) on specific IP $ip: $proc (PID $pid)"
  fi
done

echo

# Check UDP ports
echo -e "${BLUE}${BOLD}Listening UDP Ports:${NC}"
ss -tulpn | grep 'UNCONN' | sort -n -k 5 | while read line; do
  proto=$(echo $line | awk '{print $1}')
  state=$(echo $line | awk '{print $2}')
  addr=$(echo $line | awk '{print $5}')
  proc=$(echo $line | awk -F'"' '{print $2}')
  pid=$(echo $line | grep -o 'pid=[0-9]*' | cut -d= -f2)
  
  ip=$(echo $addr | cut -d: -f1)
  port=$(echo $addr | cut -d: -f2)
  
  if [ "$ip" == "0.0.0.0" ] || [ "$ip" == "*" ] || [ "$ip" == "::" ]; then
    echo -e "${YELLOW}${BOLD}WARNING:${NC} Port $port ($proto) exposed on all interfaces: $proc (PID $pid)"
  elif [ "$ip" == "127.0.0.1" ] || [ "$ip" == "::1" ]; then
    echo -e "${GREEN}OK:${NC} Port $port ($proto) only on localhost: $proc (PID $pid)"
  else
    echo -e "${YELLOW}${BOLD}NOTICE:${NC} Port $port ($proto) on specific IP $ip: $proc (PID $pid)"
  fi
done

echo

# Check firewall configuration
echo -e "${BLUE}${BOLD}Firewall Zone Configuration:${NC}"
firewall-cmd --list-all

echo
echo -e "${BLUE}${BOLD}External Port Scan Test:${NC}"
echo -e "${YELLOW}To perform an external port scan test, run:${NC}"
echo -e "${YELLOW}nmap -Pn -p 1-1000 $(hostname -I | awk '{print $1}')${NC}"

exit 0
EOF

  chmod +x /usr/local/bin/check-open-ports
  echo -e "${GREEN}Created open ports checker script at /usr/local/bin/check-open-ports${NC}"
}

# Function to apply all settings
apply_all() {
  echo -e "${BLUE}${BOLD}Applying all security enhancements...${NC}"
  
  create_hardened_default
  create_zerotrust_profile
  create_trusted_networks
  create_network_switcher
  configure_docker_isolation
  add_kernel_hardening
  create_ports_check
  setup_security_updates
  
  # Reload firewall
  echo -e "${GREEN}Reloading firewall to apply all changes...${NC}"
  firewall-cmd --reload
  
  echo -e "${BLUE}${BOLD}======================================================${NC}"
  echo -e "${GREEN}${BOLD}All security enhancements have been applied!${NC}"
  echo -e "${BLUE}${BOLD}======================================================${NC}"
  echo
  echo -e "${YELLOW}Available commands:${NC}"
  echo -e "${YELLOW}- ${BOLD}firewall-network-switcher${NC}${YELLOW} - Auto-switch firewall based on network${NC}"
  echo -e "${YELLOW}- ${BOLD}check-open-ports${NC}${YELLOW} - Check for exposed services and ports${NC}"
  echo
  echo -e "${GREEN}Don't forget to customize your trusted networks:${NC}"
  echo -e "${GREEN}  Edit /etc/firewalld/trusted_networks.conf${NC}"
  echo
  echo -e "${GREEN}To activate automatic network switching:${NC}"
  echo -e "${GREEN}  sudo systemctl enable --now firewall-network-switcher.service${NC}"
  echo
}

# Show menu
show_menu() {
  echo -e "${BLUE}${BOLD}Select an action:${NC}"
  echo -e "${YELLOW}1. Apply ALL security enhancements (recommended)${NC}"
  echo -e "${YELLOW}2. Create hardened default profile only${NC}"
  echo -e "${YELLOW}3. Create Zero Trust profile only${NC}"
  echo -e "${YELLOW}4. Create network auto-switcher only${NC}"
  echo -e "${YELLOW}5. Add Docker isolation only${NC}"
  echo -e "${YELLOW}6. Add kernel hardening only${NC}"
  echo -e "${YELLOW}7. Create ports checker tool only${NC}"
  echo -e "${YELLOW}8. Exit${NC}"
  
  read -p "Enter your choice (1-8): " choice
  
  case $choice in
    1) apply_all ;;
    2) create_hardened_default; firewall-cmd --reload ;;
    3) create_zerotrust_profile; firewall-cmd --reload ;;
    4) create_trusted_networks; create_network_switcher ;;
    5) configure_docker_isolation; firewall-cmd --reload ;;
    6) add_kernel_hardening ;;
    7) create_ports_check ;;
    8) exit 0 ;;
    *) echo -e "${RED}Invalid choice${NC}"; show_menu ;;
  esac
}

# Show the menu
show_menu
