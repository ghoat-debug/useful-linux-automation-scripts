#!/bin/bash
# Docker Zone Security Fix for Fedora 41
# This script secures the docker zone while preserving DNS functionality

# Backup current settings
echo "📋 Backing up current Docker zone settings..."
docker_zone_settings=$(sudo firewall-cmd --permanent --zone=docker --list-all)
echo "$docker_zone_settings" > /tmp/docker_zone_backup.txt
echo "✅ Backup saved to /tmp/docker_zone_backup.txt"

# Update docker zone to be more restrictive
echo "🔒 Updating Docker zone security settings..."

# 1. Change the target to REJECT (but keep the interfaces)
sudo firewall-cmd --permanent --zone=docker --set-target=REJECT

# 2. Remove sources that shouldn't be in the docker zone
sudo firewall-cmd --permanent --zone=docker --remove-source=127.0.0.1/8
sudo firewall-cmd --permanent --zone=docker --remove-source=::1/128

# 3. Remove existing rich rules (we'll recreate appropriate ones)
current_rules=$(sudo firewall-cmd --permanent --zone=docker --list-rich-rules)
while IFS= read -r rule; do
    [ -n "$rule" ] && sudo firewall-cmd --permanent --zone=docker --remove-rich-rule="$rule"
done <<< "$current_rules"

# 4. Allow only necessary services (DNS in your case)
sudo firewall-cmd --permanent --zone=docker --add-service=dns

# 5. Allow specific DNS ports for Pihole and cloudflared
sudo firewall-cmd --permanent --zone=docker --add-port=53/udp
sudo firewall-cmd --permanent --zone=docker --add-port=53/tcp

# 6. Add rich rules to ONLY allow localhost and internal Docker networks to access services
sudo firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'
sudo firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv6" source address="::1" accept'

# 7. Allow connections from Docker's internal networks
sudo firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv4" source address="172.16.0.0/12" accept'
sudo firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" accept'

# 8. Add specific ports for services you want to expose to the local network
# Uncomment and modify the examples below as needed
# sudo firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv4" port port="80" protocol="tcp" accept'
# sudo firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv4" port port="443" protocol="tcp" accept'

# 9. Apply changes
sudo firewall-cmd --reload

echo "✅ Docker zone security has been updated!"
echo "📋 New Docker zone configuration:"
sudo firewall-cmd --zone=docker --list-all