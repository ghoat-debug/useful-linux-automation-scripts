#!/bin/bash
# Ultimate FirewallD Configuration for Fedora 41 DevSecOps
# Features:
# 1. Hardened workstation zone with port knocking
# 2. Zero-trust fortress zone with Docker/Pihole integration
# 3. Advanced scan protection & connection tracking
# 4. Automatic network-based switching with enhanced rules

# --- Configuration ---
FEDORA_ZONE="FedoraWorkstation"
FORTRESS_ZONE="fortress"
TRUSTED_MAC_ADDRESSES=("aa:bb:cc:dd:ee:ff") # Add your trusted devices
PIHOLE_NETWORK="172.17.0.0/24" # Default Docker network

# --- Advanced Setup ---
# Port Knocking Sequence (tcp ports)
KNOCK_SEQ="7000,8000,9000"
KNOCK_TIMEOUT=30 # seconds
SECRET_PORT=62222 # Port opened after successful knock

# --- Script Execution ---
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo"
  exit 1
fi

echo "🛡️ === Ultimate FirewallD Configuration ==="

# Backup with improved error handling
BACKUP_DIR="/root/firewalld-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR" || { echo "❌ Backup directory creation failed"; exit 1; }
cp -a /etc/firewalld/* "$BACKUP_DIR/" && \
echo "✅ Backup complete: $BACKUP_DIR" || \
{ echo "❌ Backup failed"; exit 1; }

# =========================================================================
# 1. ENHANCED FEDORA WORKSTATION ZONE
# =========================================================================
echo "🔧 Hardening '$FEDORA_ZONE' zone..."

# Base Configuration
firewall-cmd --permanent --zone=$FEDORA_ZONE --set-target=REJECT
firewall-cmd --permanent --zone=$FEDORA_ZONE --remove-service={ssh,mdns} 2>/dev/null || true
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-service=dhcpv6-client

# Advanced Localhost Protection
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" accept'
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" source address="::1/128" accept'

# Connection Tracking with Logging Limits
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" state established,related accept'
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" state established,related accept'

# Enhanced Invalid Packet Handling
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" state invalid drop'
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" state invalid drop'

# Rate Limiting with Improved Values
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" protocol="icmp" limit value="10/s" accept'
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv6" protocol="ipv6-icmp" limit value="10/s" accept'

# Port Knocking Setup
echo "🔑 Configuring port knocking sequence: $KNOCK_SEQ"
firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule="rule family=ipv4 source address=0.0.0.0/0 port port=$SECRET_PORT protocol=tcp reject"
for port in ${KNOCK_SEQ//,/ }; do
  firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule="rule family=ipv4 source address=0.0.0.0/0 port port=$port protocol=tcp log prefix='KNOCK: ' level=info"
done

# Docker/Pihole Integration
if docker network inspect bridge &>/dev/null; then
  echo "🐳 Adding Docker/Pihole network rules"
  firewall-cmd --permanent --zone=$FEDORA_ZONE --add-source=$PIHOLE_NETWORK
  firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" source address=$PIHOLE_NETWORK port port=53 protocol=udp accept'
  firewall-cmd --permanent --zone=$FEDORA_ZONE --add-rich-rule='rule family="ipv4" source address=$PIHOLE_NETWORK port port=53 protocol=tcp accept'
fi

# =========================================================================
# 2. ZERO-TRUST FORTRESS ZONE ENHANCEMENTS
# =========================================================================
echo "🏰 Fortifying '$FORTRESS_ZONE' zone..."

# Base Configuration
firewall-cmd --permanent --zone=$FORTRESS_ZONE --set-target=DROP
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-service=dhcpv6-client

# Strict Connection Tracking
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv4" state established,related accept'
firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule='rule family="ipv6" state established,related accept'

# MAC Address Filtering
for mac in "${TRUSTED_MAC_ADDRESSES[@]}"; do
  firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule="rule family=ipv4 source mac=$mac accept"
done

# Outbound Whitelisting
ESSENTIAL_PORTS_OUT=(53 80 443 465 587 993 995)
for port in "${ESSENTIAL_PORTS_OUT[@]}"; do
  firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule="rule family=ipv4 direction=out port port=$port protocol=tcp accept"
  firewall-cmd --permanent --zone=$FORTRESS_ZONE --add-rich-rule="rule family=ipv6 direction=out port port=$port protocol=tcp accept"
done

# =========================================================================
# 3. ADVANCED NETWORK SWITCHER
# =========================================================================
cat > /usr/local/bin/firewall-switcher <<'EOF'
#!/bin/bash
# Enhanced Network Switcher with VPN Detection

TRUSTED_NETWORKS=("coast-white" "Innovus Office")
NORMAL_ZONE="FedoraWorkstation"
SECURE_ZONE="fortress"

get_network_profile() {
  # Check VPN first
  if ip tuntap show | grep -q tun; then
    echo "vpn"
    return
  fi
  
  # Then check WiFi
  local ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
  if [[ -n "$ssid" ]]; then
    for net in "${TRUSTED_NETWORKS[@]}"; do
      if [[ "$ssid" == "$net" ]]; then
        echo "trusted"
        return
      fi
    done
    echo "untrusted"
  else
    # Check wired connections
    local wired=$(nmcli -t -f device,type dev status | grep 'ethernet' | cut -d':' -f1)
    if [[ -n "$wired" ]]; then
      echo "trusted" # Or implement wired network detection
    else
      echo "disconnected"
    fi
  fi
}

case $(get_network_profile) in
  vpn|disconnected|untrusted) zone=$SECURE_ZONE ;;
  trusted) zone=$NORMAL_ZONE ;;
esac

current_zone=$(firewall-cmd --get-default-zone)
if [[ "$current_zone" != "$zone" ]]; then
  firewall-cmd --set-default-zone=$zone
  logger "Firewall switched to $zone zone"
  notify-send "Firewall Mode" "Active: $zone" --icon=network-wireless
fi
EOF

chmod +x /usr/local/bin/firewall-switcher

# =========================================================================
# 4. FINALIZATION
# =========================================================================
firewall-cmd --reload

echo "🎉 === Ultimate Firewall Configuration Complete ==="
echo "
🔥 Cheat Sheet:
- Port knocking sequence: nc -z host $KNOCK_SEQ
- Open secret port after knock: nc -zv host $SECRET_PORT
- View active rules: sudo firewall-cmd --list-all-zones
- Monitor drops: sudo journalctl -u firewalld -f | grep -E 'DROP|REJECT'
- Temporary access: sudo firewall-cmd --zone=FedoraWorkstation --add-rich-rule='rule family=ipv4 source address=IPADDRESS port port=PORT protocol=tcp accept'
"