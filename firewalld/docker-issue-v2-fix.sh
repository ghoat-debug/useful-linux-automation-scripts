#!/bin/bash
# Docker Firewall Hardening Script for Fedora
# Fixes the issue of Docker services being accessible from the network

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "🛡️ Docker Firewall Hardening Script"
echo "🔍 Fixing Docker zone configuration..."

# Backup current Docker configuration
mkdir -p /root/docker-backups
BACKUP_DIR="/root/docker-backups/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/docker "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup saved to $BACKUP_DIR"

# 1. Configure Docker zone to be more restrictive
echo "🔒 Setting Docker zone to DROP by default..."
firewall-cmd --permanent --zone=docker --set-target=DROP

# 2. Remove overly permissive Docker rules
echo "🧹 Removing overly permissive Docker rules..."
firewall-cmd --permanent --zone=docker --remove-rich-rule='rule family="ipv4" source address="10.0.0.0/8" accept' 2>/dev/null || true
firewall-cmd --permanent --zone=docker --remove-rich-rule='rule family="ipv4" source address="172.16.0.0/12" accept' 2>/dev/null || true

# 3. Only allow Docker network traffic between containers, not external access
echo "🔧 Adding proper Docker network rules..."
firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" accept'
firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv6" source address="::1/128" accept'
firewall-cmd --permanent --zone=docker --add-rich-rule='rule family="ipv4" source address="172.17.0.0/16" accept'

# 4. Create Docker daemon configuration to prevent automatic iptables manipulation
echo "📝 Creating Docker daemon configuration..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "iptables": false,
  "userland-proxy": false
}
EOF

# 5. Create a utility for selectively exposing Docker services
echo "🛠️ Creating Docker port exposure utility..."
cat > /usr/local/bin/docker-expose <<'EOF'
#!/bin/bash
# Docker Port Exposure Utility
# Usage: docker-expose [enable|disable] PORT [PROTOCOL] [SOURCE_IP]

ACTION=$1
PORT=$2
PROTO=${3:-tcp}
SOURCE=$4
ZONE="FedoraWorkstation"

if [ -z "$ACTION" ] || [ -z "$PORT" ]; then
    echo "Usage: docker-expose [enable|disable] PORT [PROTOCOL] [SOURCE_IP]"
    echo "Examples:"
    echo "  docker-expose enable 8080 tcp         # Enable port for all"
    echo "  docker-expose enable 8080 tcp 192.168.1.5  # Enable for specific IP only"
    echo "  docker-expose disable 8080 tcp        # Disable port for all"
    exit 1
fi

if [ "$ACTION" = "enable" ]; then
    if [ -n "$SOURCE" ]; then
        # Enable for specific source IP only
        firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"$PROTO\" accept"
        echo "✅ Enabled port $PORT/$PROTO for source $SOURCE in zone $ZONE"
    else
        # Enable for all sources
        firewall-cmd --zone=$ZONE --add-port=$PORT/$PROTO
        echo "✅ Enabled port $PORT/$PROTO for all clients in zone $ZONE"
    fi
elif [ "$ACTION" = "disable" ]; then
    if [ -n "$SOURCE" ]; then
        # Disable for specific source
        firewall-cmd --zone=$ZONE --remove-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"$PROTO\" accept"
        echo "✅ Disabled port $PORT/$PROTO for source $SOURCE in zone $ZONE"
    else
        # Disable for all
        firewall-cmd --zone=$ZONE --remove-port=$PORT/$PROTO
        echo "✅ Disabled port $PORT/$PROTO for all clients in zone $ZONE"
    fi
else
    echo "❌ Invalid action: $ACTION. Use enable or disable."
    exit 1
fi
EOF
chmod +x /usr/local/bin/docker-expose

# 6. Create helper for running Docker containers with localhost-only binding
echo "🔧 Creating helper for localhost-only Docker containers..."
cat > /usr/local/bin/docker-local <<'EOF'
#!/bin/bash
# Run Docker container with ports bound to localhost only
# Usage: docker-local [docker run options] IMAGE [COMMAND]

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: docker-local [docker run options] IMAGE [COMMAND]"
    echo "This helper automatically binds ports to localhost only"
    echo "Example: docker-local -p 8080:80 nginx"
    exit 0
fi

args=()
for arg in "$@"; do
    # Convert port mappings to localhost-only
    if [[ "$arg" =~ ^-p\ ([0-9]+):([0-9]+)$ ]]; then
        host_port="${BASH_REMATCH[1]}"
        container_port="${BASH_REMATCH[2]}"
        args+=("-p" "127.0.0.1:$host_port:$container_port")
    elif [[ "$arg" =~ ^-p=([0-9]+):([0-9]+)$ ]]; then
        host_port="${BASH_REMATCH[1]}"
        container_port="${BASH_REMATCH[2]}"
        args+=("-p=127.0.0.1:$host_port:$container_port")
    else
        args+=("$arg")
    fi
done

# Run docker with modified arguments
docker run "${args[@]}"
EOF
chmod +x /usr/local/bin/docker-local

# 7. Apply changes
echo "🔄 Applying changes..."
firewall-cmd --reload

echo
echo "✅ Docker Firewall Hardening Complete!"
echo "⚠️ You may need to restart Docker: sudo systemctl restart docker"
echo
echo "📋 Usage Instructions:"
echo "1. To restart Docker with new settings: sudo systemctl restart docker"
echo "2. Run containers with localhost-only ports: sudo docker-local -p 8080:80 nginx"
echo "3. To expose a Docker service port to the network: sudo docker-expose enable PORT"
echo "4. To restrict a Docker service port: sudo docker-expose disable PORT"
echo
echo "🔍 For Pi-hole and DNS specifically, run these commands after Docker restart:"
echo "   sudo docker-expose enable 53 udp  # Enable DNS UDP on the network"
echo "   sudo docker-expose enable 53 tcp  # Enable DNS TCP on the network"
echo "   sudo docker-expose enable 80 tcp  # Enable Pi-hole web interface if needed"