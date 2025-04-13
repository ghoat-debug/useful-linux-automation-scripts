#!/bin/bash
# Auto Network Security Switcher
# Automatically switches between normal and fortress mode based on connected network
# Created: April 13, 2025

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Path to store trusted networks
TRUSTED_NETWORKS_FILE="/etc/firewalld/trusted_networks.conf"
CONFIG_DIR="/etc/firewalld"
CURRENT_NETWORK=""

# Create the trusted networks file if it doesn't exist
if [ ! -f "$TRUSTED_NETWORKS_FILE" ]; then
  mkdir -p "$CONFIG_DIR"
  touch "$TRUSTED_NETWORKS_FILE"
  echo "# List of trusted network SSIDs (one per line)" > "$TRUSTED_NETWORKS_FILE"
  echo "HomeNetwork" >> "$TRUSTED_NETWORKS_FILE"
  echo "WorkNetwork" >> "$TRUSTED_NETWORKS_FILE"
  echo "✅ Created trusted networks config at $TRUSTED_NETWORKS_FILE"
  echo "Please edit this file to add your actual trusted networks."
fi

# Function to check if current network is trusted
is_trusted_network() {
  local current_ssid="$1"

  if [ -z "$current_ssid" ] || [ "$current_ssid" == "--" ]; then
    # No WiFi connection
    return 1
  fi

  if grep -q "^$current_ssid$" "$TRUSTED_NETWORKS_FILE"; then
    return 0  # Found in trusted list
  else
    return 1  # Not found in trusted list
  fi
}

# Function to get current WiFi SSID
get_current_ssid() {
  local ssid

  # Try iw (more modern tool)
  if command -v iw &> /dev/null; then
    ssid=$(iw dev | grep ssid | awk '{print $2}')
    if [ -n "$ssid" ]; then
      echo "$ssid"
      return
    fi
  fi

  # Try nmcli (NetworkManager)
  if command -v nmcli &> /dev/null; then
    ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    if [ -n "$ssid" ]; then
      echo "$ssid"
      return
    fi
  fi

  # Try iwconfig (older systems)
  if command -v iwconfig &> /dev/null; then
    ssid=$(iwconfig 2>/dev/null | grep ESSID | awk -F: '{print $2}' | tr -d '"')
    if [ -n "$ssid" ]; then
      echo "$ssid"
      return
    fi
  fi

  # No WiFi connection found
  echo "--"
}

# Function to apply appropriate firewall zone
apply_firewall_zone() {
  local current_ssid="$1"
  local current_zone
  current_zone=$(firewall-cmd --get-default-zone)

  if is_trusted_network "$current_ssid"; then
    if [ "$current_zone" != "FedoraWorkstation" ]; then
      echo "🔓 Connected to trusted network: $current_ssid"
      echo "🔄 Switching to normal security mode..."
      firewall-cmd --set-default-zone=FedoraWorkstation
      echo "✅ Security mode switched to FedoraWorkstation"
    else
      echo "✅ Already in normal security mode for trusted network: $current_ssid"
    fi
  else
    if [ "$current_zone" != "fortress" ]; then
      echo "⚠️ Connected to untrusted network: $current_ssid"
      echo "🔄 Activating fortress security mode..."
      firewall-cmd --set-default-zone=fortress
      echo "✅ FORTRESS MODE ACTIVATED for untrusted network"
    else
      echo "✅ Already in fortress mode for untrusted network: $current_ssid"
    fi
  fi
}

# Command line options
case "$1" in
  --help|-h)
    echo "Auto Network Security Switcher"
    echo "Usage:"
    echo "  $0                     Check and switch security mode based on current network"
    echo "  $0 --add SSID          Add a network to trusted networks list"
    echo "  $0 --remove SSID       Remove a network from trusted networks list"
    echo "  $0 --list              List all trusted networks"
    echo "  $0 --status            Show current network and security status"
    echo "  $0 --daemon            Run in daemon mode (check every 30 seconds)"
    echo "  $0 --setup-service     Install as a systemd service"
    echo "  $0 --help              Show this help message"
    exit 0
    ;;
  --add)
    if [ -z "$2" ]; then
      echo "Error: Please specify a network SSID to add"
      exit 1
    fi
    if grep -q "^$2$" "$TRUSTED_NETWORKS_FILE"; then
      echo "Network '$2' is already in trusted networks list."
    else
      echo "$2" >> "$TRUSTED_NETWORKS_FILE"
      echo "✅ Added '$2' to trusted networks list."
    fi
    exit 0
    ;;
  --remove)
    if [ -z "$2" ]; then
      echo "Error: Please specify a network SSID to remove"
      exit 1
    fi
    if grep -q "^$2$" "$TRUSTED_NETWORKS_FILE"; then
      sed -i "/^$2$/d" "$TRUSTED_NETWORKS_FILE"
      echo "✅ Removed '$2' from trusted networks list."
    else
      echo "Network '$2' is not in trusted networks list."
    fi
    exit 0
    ;;
  --list)
    echo "📋 Trusted Networks:"
    grep -v "^#" "$TRUSTED_NETWORKS_FILE" | sort
    exit 0
    ;;
  --status)
    current_ssid=$(get_current_ssid)
    current_zone=$(firewall-cmd --get-default-zone)

    echo "Current Network: $current_ssid"
    echo "Current Security Zone: $current_zone"

    if is_trusted_network "$current_ssid"; then
      echo "Trust Status: ✅ TRUSTED"
    else
      echo "Trust Status: ⚠️ UNTRUSTED"
    fi
    exit 0
    ;;
  --daemon)
    echo "🔄 Starting daemon mode (press Ctrl+C to stop)..."
    while true; do
      current_ssid=$(get_current_ssid)

      # Only react if the network changed
      if [ "$current_ssid" != "$CURRENT_NETWORK" ]; then
        CURRENT_NETWORK="$current_ssid"
        apply_firewall_zone "$current_ssid"
      fi

      sleep 30
    done
    ;;
  --setup-service)
    # Create systemd service file
    cat > /etc/systemd/system/network-security-switcher.service << EOF
[Unit]
Description=Auto Network Security Switcher
After=network.target NetworkManager.service

[Service]
Type=simple
ExecStart=$(readlink -f "$0") --daemon
Restart=always
RestartSec=30
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable network-security-switcher.service
    systemctl start network-security-switcher.service

    echo "✅ Network Security Switcher service installed and started!"
    echo "   Check status with: systemctl status network-security-switcher"
    exit 0
    ;;
  *)
    # Default behavior: check once and apply
    current_ssid=$(get_current_ssid)
    apply_firewall_zone "$current_ssid"
    ;;
esac
