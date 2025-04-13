#!/bin/bash
# Enhanced FirewallD Configuration for Fedora 41
# A comprehensive setup for DevSecOps professionals
# Created: April 13, 2025

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

echo "=== Enhancing FirewallD Configuration for DevSecOps ==="

# Backup current configuration
BACKUP_DIR="/root/firewalld-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/firewalld/* "$BACKUP_DIR"
echo "✅ Backed up current firewalld configuration to $BACKUP_DIR"

# ==========================================
# 1. IMPROVE DEFAULT ZONE (FedoraWorkstation)
# ==========================================
echo "🔄 Enhancing default FedoraWorkstation zone..."

# Enable basic port scan protection
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" limit value="5/m" accept'
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv6" limit value="5/m" accept'

# Drop invalid packets - helps prevent various scan techniques
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule ct state INVALID drop'

# Rate limit new connections to prevent SYN floods
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule tcp flags="syn" ct state NEW limit value="10/s" accept'

# Block null scans (SYN packets with no flags set)
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule tcp flags="FIN,SYN,RST,ACK" tcp-flags="SYN" drop'

# Enable logging for rejected packets (helpful for debugging)
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule pkttype="broadcast" log prefix="BROADCAST: " level="warning" limit value="5/m" drop'

# Allow localhost services only from localhost
# This ensures services you test locally are only accessible from your machine
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'
firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv6" source address="::1" accept'

# ==========================================
# 2. CREATE FORTRESS ZONE FOR PUBLIC NETWORKS
# ==========================================
echo "🔒 Creating fortress zone for public networks..."

# Create new "fortress" zone for ultra-secure public usage
firewall-cmd --permanent --new-zone=fortress

# Set target to DROP by default (zero trust model)
firewall-cmd --permanent --zone=fortress --set-target=DROP

# Strict connection tracking
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule ct state RELATED,ESTABLISHED accept'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule ct state INVALID drop'

# Outbound connections: only essential services
# Allow DNS (your local Pi-hole will handle this)
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv4" port port=53 protocol=udp outbound accept'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv4" port port=53 protocol=tcp outbound accept'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv6" port port=53 protocol=udp outbound accept'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv6" port port=53 protocol=tcp outbound accept'

# Allow HTTPS (443) for browsing
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv4" port port=443 protocol=tcp outbound accept'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv6" port port=443 protocol=tcp outbound accept'

# Allow HTTP (80) for browsing
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv4" port port=80 protocol=tcp outbound accept'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv6" port port=80 protocol=tcp outbound accept'

# Block all incoming traffic except DHCP and ICMPv6 for network discovery
firewall-cmd --permanent --zone=fortress --add-service=dhcpv6-client

# Rate limit ICMP to prevent ICMP floods but allow basic connectivity checks
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule protocol value="icmp" limit value="10/s" accept'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule family="ipv6" protocol value="ipv6-icmp" limit value="10/s" accept'

# Extra security: log and drop port scans
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule tcp flags="FIN,SYN,RST,PSH,ACK,URG" tcp-flags="FIN,SYN,RST,PSH,ACK,URG" log prefix="XMAS_SCAN: " level="warning" limit value="10/m" drop'
firewall-cmd --permanent --zone=fortress --add-rich-rule='rule tcp flags="FIN" tcp-flags="FIN" log prefix="FIN_SCAN: " level="warning" limit value="10/m" drop'

# ==========================================
# 3. APPLY CHANGES
# ==========================================
echo "🔄 Applying changes..."
firewall-cmd --reload

echo "✅ Enhanced firewall configuration complete!"
echo
echo "Current default zone: $(firewall-cmd --get-default-zone)"
echo
echo "To switch to fortress mode: sudo firewall-cmd --set-default-zone=fortress"
echo "To switch back to normal mode: sudo firewall-cmd --set-default-zone=FedoraWorkstation"
