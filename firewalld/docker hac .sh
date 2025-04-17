#!/bin/bash
# Docker Firewall Security Fix for Fedora 41
# This script fixes Docker bypassing firewalld rules

set -e

log_step() {
    echo
    echo "🔶 $1"
}

# =========================================================================
# 1. FIX DOCKER ZONE CONFIGURATION
# =========================================================================
log_step "Reconfiguring Docker firewall zone..."

# Set Docker zone to REJECT by default
sudo firewall-cmd --permanent --zone=docker --set-target=REJECT

# Remove localhost sources from Docker zone (these belong in main zone)
sudo firewall-cmd --permanent --zone=docker --remove-source=127.0.0.1/8 2>/dev/null || true
sudo firewall-cmd --permanent --zone=docker --remove-source=::1/128 2>/dev/null || true

# Allow only Docker-specific networks for container-to-container communication
echo "Adding Docker subnet rules..."
docker_networks=$(docker network ls --format "{{.ID}}")
for network_id in $docker_networks; do
  subnet=$(docker network inspect $network_id --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' | tr -d '\n')
  if [ -n "$subnet" ]; then
    echo "  - Adding rule for subnet: $subnet"
    sudo firewall-cmd --permanent --zone=docker --add-rich-rule="rule family=\"ipv4\" source address=\"$subnet\" accept"
  fi
done

# Ensure essential services for Docker
sudo firewall-cmd --permanent --zone=docker --add-service=dns
sudo firewall-cmd --permanent --zone=docker --add-service=dhcp
sudo firewall-cmd --permanent --zone=docker --add-service=dhcpv6-client

# =========================================================================
# 2. CREATE DOCKER SERVICE EXPOSURE TOOL
# =========================================================================
log_step "Creating Docker service exposure utility..."

cat > /usr/local/bin/docker-expose <<'EOF'
#!/bin/bash
# Docker Service Exposure Utility
# Usage: docker-expose [enable|disable] PORT [SOURCE]

ACTION=$1
PORT=$2
SOURCE=$3
ZONE="FedoraWorkstation"

if [ -z "$ACTION" ] || [ -z "$PORT" ]; then
    echo "Usage: docker-expose [enable|disable] PORT [SOURCE]"
    echo "Example: docker-expose enable 8080"
    echo "Example: docker-expose enable 8080 192.168.1.5"
    exit 1
fi

if [ "$ACTION" = "enable" ]; then
    if [ -n "$SOURCE" ]; then
        # Enable port only for specific source IP
        sudo firewall-cmd --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"tcp\" accept"
        echo "Exposed Docker port $PORT for source $SOURCE in zone $ZONE"
    else
        # Enable port for all clients
        sudo firewall-cmd --zone=$ZONE --add-port=$PORT/tcp
        echo "Exposed Docker port $PORT for all clients in zone $ZONE"
    fi
elif [ "$ACTION" = "disable" ]; then
    if [ -n "$SOURCE" ]; then
        # Remove specific source rule
        sudo firewall-cmd --zone=$ZONE --remove-rich-rule="rule family=\"ipv4\" source address=\"$SOURCE\" port port=\"$PORT\" protocol=\"tcp\" accept"
        echo "Disabled Docker port $PORT for source $SOURCE in zone $ZONE"
    else
        # Disable port for all
        sudo firewall-cmd --zone=$ZONE --remove-port=$PORT/tcp
        echo "Disabled Docker port $PORT for all clients in zone $ZONE"
    fi
else
    echo "Invalid action: $ACTION. Use enable or disable."
    exit 1
fi
EOF

chmod +x /usr/local/bin/docker-expose

# =========================================================================
# 3. DOCKER DAEMON CONFIGURATION
# =========================================================================
log_step "Updating Docker daemon configuration..."

sudo mkdir -p /etc/docker
cat > /tmp/daemon.json <<EOF
{
  "iptables": true,
  "userland-proxy": false,
  "ip": "127.0.0.1"
}
EOF

# Check if file exists and if it's different
if [ ! -f /etc/docker/daemon.json ] || ! cmp -s /tmp/daemon.json /etc/docker/daemon.json; then
    sudo mv /tmp/daemon.json /etc/docker/daemon.json
    echo "Docker daemon configuration updated. You'll need to restart Docker: sudo systemctl restart docker"
else
    rm /tmp/daemon.json
    echo "Docker daemon configuration unchanged"
fi

# =========================================================================
# 4. CREATE A GUIDE FOR EXISTING CONTAINERS
# =========================================================================
log_step "Creating Docker container migration guide..."

cat > ~/docker-migration-guide.txt <<'EOF'
==========================================================================
DOCKER CONTAINER MIGRATION GUIDE
==========================================================================

To fix your existing containers for proper firewall isolation:

1. For containers that should ONLY be accessible from localhost:
   ------------------------------------------------------------
   
   # Stop the existing container
   docker stop container_name
   
   # Remove it (data volumes will be preserved)
   docker rm container_name
   
   # Recreate with localhost binding
   docker run -p 127.0.0.1:PORT:PORT [other options] image_name
   
   Example:
   docker run -p 127.0.0.1:8080:80 -d --name webapp nginx

2. For containers that need network access:
   ---------------------------------------
   
   # First recreate them with localhost binding
   docker run -p 127.0.0.1:PORT:PORT [other options] image_name
   
   # Then use the docker-expose utility to explicitly allow network access
   docker-expose enable PORT
   
   # To allow access only from a specific IP
   docker-expose enable PORT 192.168.1.5
   
   # To later disable network access
   docker-expose disable PORT

3. For your DNS servers (PiHole and Cloudflared):
   --------------------------------------------
   
   These need special handling. Make sure they're accessible on the
   required ports, but only by the appropriate sources.
   
   For example, PiHole DNS should be accessible on port 53, but you
   probably want to limit access to your local network.
   
   docker-expose enable 53 192.168.0.0/24

==========================================================================
EOF

echo "Migration guide created at ~/docker-migration-guide.txt"

# =========================================================================
# FINALIZATION
# =========================================================================
log_step "Applying changes..."

# Reload firewall to apply changes
sudo firewall-cmd --reload

echo 
echo "✅ Docker Firewall Configuration Fixed!"
echo "🔥 Docker Zone Configuration:"
sudo firewall-cmd --list-all --zone=docker
echo
echo "💡 Next Steps:"
echo "1. Read the migration guide at ~/docker-migration-guide.txt"
echo "2. Restart Docker with: sudo systemctl restart docker"
echo "3. Update your containers to use localhost binding when appropriate"
echo "4. Use docker-expose to selectively allow network access to services"
echo