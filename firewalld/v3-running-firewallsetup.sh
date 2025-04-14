#!/bin/bash
# Fedora 41 Firewall Hardening Script (firewalld 2.2.3 compatible)
# Security Targets:
# 1. Default zone: Developer-friendly with localhost access
# 2. Fortress zone: Zero-trust public network protection
# 3. Anti-scan/anti-flood measures
# 4. Secure automatic network switching

# --- Configuration ---
FEDORA_ZONE="FedoraWorkstation"
FORTRESS_ZONE="fortress"
KNOCK_PORTS=(7000 8000 9000)  # Port knocking sequence
SSH_PORT=22

# --- Firewalld Compatibility Setup ---
set -e
FIREWALLD_VERSION=$(firewall-cmd --version 2>/dev/null | cut -d' ' -f1)

# --- Helper Functions ---
add_direct_rule() {
    family=$1
    chain=$2
    rule=$3
    echo "   - [Direct] $family $chain: $rule"
    firewall-cmd --permanent --direct --add-rule $family filter $chain 0 $rule
}

# --- Initial Checks ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit 1
fi

if [[ "$FIREWALLD_VERSION" < "0.7.0" ]]; then
    echo "⚠️  Warning: Older firewalld version detected - using compatibility mode"
fi

echo "🛡️ Starting Fedora 41 Firewall Hardening (firewalld ${FIREWALLD_VERSION})"

# --- Backup Original Config ---
BACKUP_BASE="/root/firewalld-backups"
BACKUP_DIR="${BACKUP_BASE}/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔄 Backing up current configuration..."
copy_items=(
    /etc/firewalld/firewalld.conf
    /etc/firewalld/*.xml
    /etc/firewalld/icmptypes
    /etc/firewalld/services
    /etc/firewalld/ipsets
)

for item in "${copy_items[@]}"; do
    if [ -e "$item" ]; then
        cp -a "$item" "$BACKUP_DIR/" 2>/dev/null || echo "⚠️  Failed to copy $item"
    fi
done

echo "✅ Backup complete: ${BACKUP_DIR}"

# =========================================================================
# 1. HARDEN DEFAULT ZONE (FedoraWorkstation)
# =========================================================================
echo
echo "🔧 Configuring ${FEDORA_ZONE} zone..."

# Base configuration
firewall-cmd --permanent --zone=${FEDORA_ZONE} --set-target=REJECT
firewall-cmd --permanent --zone=${FEDORA_ZONE} --remove-service=ssh 2>/dev/null || true
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-service=dhcpv6-client

# Localhost access
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'
firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-rich-rule='rule family="ipv6" source address="::1" accept'

# Direct rules for advanced protection
add_direct_rule ipv4 INPUT "-m conntrack --ctstate INVALID -j DROP"
add_direct_rule ipv6 INPUT "-m conntrack --ctstate INVALID -j DROP"
add_direct_rule ipv4 INPUT "! -i lo -s 127.0.0.0/8 -j DROP"
add_direct_rule ipv6 INPUT "! -i lo -s ::1/128 -j DROP"

# SYN Flood protection
add_direct_rule ipv4 INPUT "-p tcp --syn -m limit --limit 15/s -j ACCEPT"
add_direct_rule ipv6 INPUT "-p tcp --syn -m limit --limit 15/s -j ACCEPT"

# =========================================================================
# 2. FORTRESS ZONE (Zero-Trust Configuration)
# =========================================================================
echo
echo "🏰 Creating ${FORTRESS_ZONE} zone..."

# Zone creation
firewall-cmd --permanent --new-zone=${FORTRESS_ZONE} 2>/dev/null || true
firewall-cmd --permanent --zone=${FORTRESS_ZONE} --set-target=DROP

# Essential outbound rules
declare -A FORTRESS_OUT=(
    ["DNS_TCP"]='port port="53" protocol="tcp" direction="out"'
    ["DNS_UDP"]='port port="53" protocol="udp" direction="out"'
    ["HTTP"]='port port="80" protocol="tcp" direction="out"'
    ["HTTPS"]='port port="443" protocol="tcp" direction="out"'
)

for rule in "${!FORTRESS_OUT[@]}"; do
    firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule="rule family=\"ipv4\" ${FORTRESS_OUT[$rule]} accept"
    firewall-cmd --permanent --zone=${FORTRESS_ZONE} --add-rich-rule="rule family=\"ipv6\" ${FORTRESS_OUT[$rule]} accept"
done

# Fortress direct rules
add_direct_rule ipv4 INPUT "-p icmp -m limit --limit 5/s -j ACCEPT"
add_direct_rule ipv6 INPUT "-p ipv6-icmp -m limit --limit 5/s -j ACCEPT"

# =========================================================================
# 3. PORT KNOCKING SETUP
# =========================================================================
echo
echo "🔑 Configuring Port Knocking (SSH on ${SSH_PORT})..."

# Add knock ports to default zone
for port in "${KNOCK_PORTS[@]}"; do
    firewall-cmd --permanent --zone=${FEDORA_ZONE} --add-port=${port}/tcp
done

# Create knockd script
cat > /usr/local/bin/knockd-listener <<EOF
#!/bin/bash
# Port knocking implementation for firewalld 2.2.3
# Monitor logs for knock sequence: ${KNOCK_PORTS[@]}

tail -Fn0 /var/log/messages | while read line; do
    if echo "\$line" | grep -q "DPT=${KNOCK_PORTS[0]}"; then
        IP=\$(echo "\$line" | grep -oP 'SRC=\K[0-9.]+')
        echo "\$(date) - Knock start from \$IP" >> /var/log/knockd.log
        echo "1" > "/tmp/knock-\$IP"
    elif [ -n "\$IP" ] && [ -f "/tmp/knock-\$IP" ]; then
        COUNT=\$(cat "/tmp/knock-\$IP")
        if echo "\$line" | grep -q "DPT=${KNOCK_PORTS[\$COUNT]}"; then
            echo "\$((COUNT+1))" > "/tmp/knock-\$IP"
            if [ \$((COUNT+1)) -eq ${#KNOCK_PORTS[@]} ]; then
                echo "\$(date) - Valid knock from \$IP" >> /var/log/knockd.log
                firewall-cmd --zone=${FEDORA_ZONE} --add-rich-rule="rule family=\"ipv4\" source address=\"\$IP\" port port=\"${SSH_PORT}\" protocol=\"tcp\" accept" --timeout=30
                rm -f "/tmp/knock-\$IP"
            fi
        fi
    fi
done
EOF

chmod +x /usr/local/bin/knockd-listener

# Create systemd service
cat > /etc/systemd/system/knockd.service <<EOF
[Unit]
Description=Port Knock Daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/knockd-listener
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now knockd.service

# =========================================================================
# 4. NETWORK AUTO-SWITCHING
# =========================================================================
echo
echo "🔄 Configuring Network Auto-Switching..."

# Create switcher script
cat > /usr/local/bin/firewall-switcher <<'EOF'
#!/bin/bash
TRUSTED_NETWORKS=("HomeLAN" "CorporateVPN")
NORMAL_ZONE="FedoraWorkstation"
SECURE_ZONE="fortress"

CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | cut -d: -f2)
VPN_ACTIVE=$(ip tuntap show | grep -qc tun0)

if [ $VPN_ACTIVE -gt 0 ]; then
    firewall-cmd --set-default-zone=${NORMAL_ZONE}
elif [ -z "$CURRENT_SSID" ]; then
    firewall-cmd --set-default-zone=${SECURE_ZONE}
elif printf '%s\n' "${TRUSTED_NETWORKS[@]}" | grep -qx "$CURRENT_SSID"; then
    firewall-cmd --set-default-zone=${NORMAL_ZONE}
else
    firewall-cmd --set-default-zone=${SECURE_ZONE}
fi
EOF

chmod +x /usr/local/bin/firewall-switcher

# Create NetworkManager dispatcher
cat > /etc/NetworkManager/dispatcher.d/99-firewall-switch <<'EOF'
#!/bin/bash
[ "$2" = "up" ] || [ "$2" = "down" ] && /usr/local/bin/firewall-switcher
EOF

chmod +x /etc/NetworkManager/dispatcher.d/99-firewall-switch

# =========================================================================
# FINALIZATION
# =========================================================================
echo
echo "🎯 Finalizing Configuration..."
firewall-cmd --reload

echo
echo "✅ Hardening Complete!"
echo "🔥 Default Zone: $(firewall-cmd --get-default-zone)"
echo "🔒 Active Zones:"
firewall-cmd --get-active-zones
echo
echo "💡 Usage Tips:"
echo "- Trusted Networks: Edit /usr/local/bin/firewall-switcher"
echo "- Port Knocking: knock ${KNOCK_PORTS[@]} then ssh"
echo "- Logs: journalctl -u knockd -f"