#!/bin/bash
# Fedora 41 Hardened Firewalld Configuration
# Created for a DevSecOps professional with Docker, KDE Connect, and various network services
# Purpose: Create a hardened default profile and ultra-secure zero trust profile

# PART 1: SYSTEM HARDENING - KERNEL PARAMETERS
# These parameters help prevent various network-based attacks and improve security

echo "[+] Setting up secure kernel parameters..."
sudo sysctl -w net.ipv4.tcp_syncookies=1
sudo sysctl -w net.ipv4.conf.all.rp_filter=1
sudo sysctl -w net.ipv4.conf.default.rp_filter=1
sudo sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1
sudo sysctl -w net.ipv4.conf.all.accept_redirects=0
sudo sysctl -w net.ipv4.conf.all.secure_redirects=0
sudo sysctl -w net.ipv4.conf.all.send_redirects=0
sudo sysctl -w net.ipv4.conf.all.accept_source_route=0
sudo sysctl -w net.ipv4.conf.all.log_martians=1

# Make kernel parameters permanent
sudo bash -c 'cat << EOF > /etc/sysctl.d/90-security.conf
# Prevent SYN flood attacks
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_syn_retries=5

# IP spoofing protection
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0

# Disable IP source routing
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

# Block broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts=1

# Enable bad error message protection
net.ipv4.icmp_ignore_bogus_error_responses=1

# Enable logging of martian packets
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1

# Enable TCP timestamps - useful for monitoring
net.ipv4.tcp_timestamps=1

# Increase TCP max buffer size
net.core.rmem_max=8388608
net.core.wmem_max=8388608
EOF'

# Apply the sysctl changes
sudo sysctl -p /etc/sysctl.d/90-security.conf

# PART 2: HARDENING DEFAULT ZONE - FEDORAWORKSTATION
echo "[+] Hardening FedoraWorkstation zone (default zone)..."

# Block ICMP timestamp requests
sudo firewall-cmd --permanent --add-icmp-block=timestamp-request

# Drop invalid packets (crucial for protecting against port scanning)
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m state --state INVALID -j DROP
sudo firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -m state --state INVALID -j DROP

# Set up anti-port scanning measures with connection limiting
# This helps prevent port scans by limiting the rate of new connections
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp --syn -m limit --limit 1/s --limit-burst 4 -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -p tcp --syn -j DROP
sudo firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -p tcp --syn -m limit --limit 1/s --limit-burst 4 -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 1 -p tcp --syn -j DROP

# Block and log port scanning attempts with recent module
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m recent --name portscan --rcheck --seconds 86400 -j DROP
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m recent --name portscan --remove
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK RST -m limit --limit 1/s -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK RST -m recent --name portscan --set -j DROP

# Enable logging for dropped packets
sudo firewall-cmd --permanent --set-log-denied=all

# Allow established and related connections
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" ct state="established,related" accept'
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv6" ct state="established,related" accept'

# Protect SSH with rate limiting
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule service name="ssh" accept limit value="5/m"'

# Allow only localhost to access Docker-related ports by default
# This ensures your Docker services are only accessible locally unless explicitly configured
echo "[+] Setting up Docker port rules..."
for port in 5053 53 88 20019 20017 10019 10017; do
    sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule="rule family=\"ipv4\" port port=\"$port\" protocol=\"tcp\" source address=\"127.0.0.1\" accept"
    sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule="rule family=\"ipv4\" port port=\"$port\" protocol=\"tcp\" drop"
    sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule="rule family=\"ipv6\" port port=\"$port\" protocol=\"tcp\" source address=\"::1\" accept"
    sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule="rule family=\"ipv6\" port port=\"$port\" protocol=\"tcp\" drop"
done

# PART 3: CREATING ULTRA-SECURE ZERO TRUST ZONE
echo "[+] Creating ZeroTrust zone profile..."

# Create the new zone (skip if it already exists)
sudo firewall-cmd --get-zones | grep -q "zerotrust" || sudo firewall-cmd --permanent --new-zone=zerotrust

# Configure the ZeroTrust zone with ultra-secure settings
sudo firewall-cmd --permanent --zone=zerotrust --set-target=DROP
sudo firewall-cmd --permanent --zone=zerotrust --set-description="Ultra-secure zero trust profile for public networks"

# Only allow essential outbound services
sudo firewall-cmd --permanent --zone=zerotrust --add-service=dns
sudo firewall-cmd --permanent --zone=zerotrust --add-service=https

# Allow established connections
sudo firewall-cmd --permanent --zone=zerotrust --add-rich-rule='rule family="ipv4" ct state="established,related" accept'
sudo firewall-cmd --permanent --zone=zerotrust --add-rich-rule='rule family="ipv6" ct state="established,related" accept'

# Explicitly drop and log all new incoming connections
sudo firewall-cmd --permanent --zone=zerotrust --add-rich-rule='rule family="ipv4" ct state="new" ct direction="in" log prefix="ZEROTRUST_NEW_INCOMING: " level="info" limit value="3/m" drop'
sudo firewall-cmd --permanent --zone=zerotrust --add-rich-rule='rule family="ipv6" ct state="new" ct direction="in" log prefix="ZEROTRUST_NEW_INCOMING: " level="info" limit value="3/m" drop'

# Apply defensive rules to protect against common attacks
sudo firewall-cmd --permanent --zone=zerotrust --add-icmp-block=timestamp-request
sudo firewall-cmd --permanent --zone=zerotrust --add-icmp-block=address-mask-request
sudo firewall-cmd --permanent --zone=zerotrust --add-icmp-block=redirect

# Allow loopback traffic
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -i lo -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -i lo -j ACCEPT

# Apply changes
echo "[+] Applying firewall rules..."
sudo firewall-cmd --reload

# Display results
echo "[+] Configuration complete!"
echo "Default hardened zone: $(sudo firewall-cmd --get-default-zone)"
echo "ZeroTrust profile is now available"
echo
echo "Use 'sudo firewall-cmd --set-default-zone=zerotrust' to manually activate Zero Trust mode"
echo "Or use the auto-switching script for dynamic profile management"
