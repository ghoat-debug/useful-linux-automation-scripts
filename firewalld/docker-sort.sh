#!/bin/bash
# Docker Firewall Integration for Fedora 41
# This script enforces firewall controls on Docker published ports

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "🐋 Setting up Docker Firewall Integration for Fedora 41..."

# =========================================================================
# 1. DIRECT RULES TO CONTROL DOCKER
# =========================================================================
echo "Adding direct rules to control Docker traffic..."

# Get the main network interface that we need to protect
MAIN_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
echo "Main interface that needs protection: $MAIN_INTERFACE"

# Convenience function for adding direct rules
add_direct_rule() {
    echo "Adding rule: $@"
    firewall-cmd --permanent --direct --add-rule "$@"
}

# These rules ensure incoming connections to Docker published ports
# must go through your main zone's filtering
add_direct_rule ipv4 filter FORWARD 0 -i $MAIN_INTERFACE -o br-+ -m conntrack --ctstate NEW -j FedoraWorkstation_FORWARD
add_direct_rule ipv4 filter FORWARD 0 -i $MAIN_INTERFACE -o docker0 -m conntrack --ctstate NEW -j FedoraWorkstation_FORWARD

# Allow established connections
add_direct_rule ipv4 filter FORWARD 0 -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
add_direct_rule ipv4 filter FORWARD 0 -o br-+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# =========================================================================
# 2. DOCKER PORT PROTECTION SCRIPT
# =========================================================================
echo "Creating Docker port protection tools..."

# Create a script that automatically blocks Docker published ports
cat > /usr/local/bin/docker-firewall <<'EOF'
#!/bin/bash
# Docker Firewall Protection Script

# Get active zone
ACTIVE_ZONE=$(firewall-cmd --get-default-zone)
echo "Active zone: $ACTIVE_ZONE"

# Get all Docker published ports
echo "Scanning for Docker published ports..."
docker ps --format "{{.Ports}}" | grep -oP "0.0.0.0:\K\d+" | sort -u | while read port; do
    if [ -n "$port" ]; then
        echo "Found Docker published port: $port"
        
        # Check if this port is already controlled
        if ! firewall-cmd --zone=$ACTIVE_ZONE --query-rich-rule="rule family=\"ipv4\" port port=\"$port\" protocol=\"tcp\" reject" &>/dev/null; then
            echo "Adding protection for port $port"
            
            # Block external access to this port
            firewall-cmd --zone=$ACTIVE_ZONE --add-rich-rule="rule family=\"ipv4\" port port=\"$port\" protocol=\"tcp\" reject"
            
            # Allow localhost access
            firewall-cmd --zone=$ACTIVE_ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"127.0.0.1\" port port=\"$port\" protocol=\"tcp\" accept"
        else
            echo "Port $port already protected"
        fi
    fi
done

echo "Docker protection complete"
EOF

chmod +x /usr/local/bin/docker-firewall

# Create a systemd service to run this on boot and when Docker changes
cat > /etc/systemd/system/docker-firewall.service <<EOF
[Unit]
Description=Docker Firewall Protection
After=docker.service firewalld.service
Wants=docker.service firewalld.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-firewall
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Create a helper script to enable specific Docker ports when needed
cat > /usr/local/bin/docker-port <<'EOF'
#!/bin/bash
# Utility to enable/disable network access to Docker published ports

ACTION=$1
PORT=$2
SOURCE=$3
ZONE=$(firewall-cmd --get-default-zone)

if [ -z "$ACTION" ] || [ -z "$PORT" ]; then
    echo "Usage: docker-port [enable|disable] PORT [SOURCE_IP]"
    echo "Example: docker-port enable 8080"
    echo "Example: docker-port enable 3000 192.168.1.10"
    exit 1
fi

if [ "$ACTION" = "enable" ]; then
    # First, remove the reject rule for this port
    firewall-cmd --zone=$ZONE --remove-rich-rule="rule family=\"ipv4\" port port=\"$PORT\" protocol=\"tcp\" reject"
    
    if [ -n "$SOURCE" ]; then
        # Add a rule to allow access from specific source
        firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"tcp\" accept"
        echo "Enabled Docker port $PORT for source IP $SOURCE"
    else
        # Add a rule to allow access from anywhere
        firewall-cmd --zone=$ZONE --add-port=$PORT/tcp
        echo "Enabled Docker port $PORT for all network access"
    fi
    
    # Make sure localhost still has access
    firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"127.0.0.1\" port port=\"$PORT\" protocol=\"tcp\" accept"
    
elif [ "$ACTION" = "disable" ]; then
    # Remove any existing rules for this port
    firewall-cmd --zone=$ZONE --remove-port=$PORT/tcp
    
    if [ -n "$SOURCE" ]; then
        firewall-cmd --zone=$ZONE --remove-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"tcp\" accept"
    fi
    
    # Add back the reject and localhost rules
    firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" port port=\"$PORT\" protocol=\"tcp\" reject"
    firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"127.0.0.1\" port port=\"$PORT\" protocol=\"tcp\" accept"
    
    echo "Disabled network access to Docker port $PORT"
else
    echo "Invalid action: $ACTION. Use enable or disable."
    exit 1
fi
EOF

chmod +x /usr/local/bin/docker-port

# =========================================================================
# 3. ENABLE AND APPLY
# =========================================================================
systemctl daemon-reload
systemctl enable docker-firewall.service
systemctl start docker-firewall.service

# Apply changes
firewall-cmd --reload

echo "✅ Docker Firewall Integration Complete!"
echo 
echo "▶️ Your Docker containers are now protected by your firewalld zones"
echo "▶️ Docker published ports are only accessible from localhost by default"
echo
echo "To enable network access to a Docker port:"
echo "    sudo docker-port enable PORT_NUMBER [optional_source_ip]"
echo
echo "To disable network access to a Docker port:"
echo "    sudo docker-port disable PORT_NUMBER"
echo
echo "Example: sudo docker-port enable 8080 192.168.1.100"