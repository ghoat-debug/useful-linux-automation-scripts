# FirewallD Cheatsheet for DevSecOps

## Basic Commands

### Status and Information
```bash
# Check if firewalld is running
sudo systemctl status firewalld

# Check firewalld state
sudo firewall-cmd --state

# Get default zone
sudo firewall-cmd --get-default-zone

# List all available zones
sudo firewall-cmd --get-zones

# List active zones and their interfaces
sudo firewall-cmd --get-active-zones

# List everything added for a zone
sudo firewall-cmd --list-all
sudo firewall-cmd --zone=public --list-all

# List all available services
sudo firewall-cmd --get-services
```

### Zone Management
```bash
# Set default zone
sudo firewall-cmd --set-default-zone=drop

# Add an interface to a zone
sudo firewall-cmd --zone=trusted --add-interface=eth0 --permanent

# Change zone of an interface
sudo firewall-cmd --zone=drop --change-interface=eth0 --permanent
```

### Service Management
```bash
# Allow a service
sudo firewall-cmd --zone=public --add-service=https --permanent

# Remove a service
sudo firewall-cmd --zone=public --remove-service=http --permanent

# Create a new service
sudo firewall-cmd --new-service=myservice --permanent
sudo firewall-cmd --service=myservice --set-description="My Custom Service" --permanent
sudo firewall-cmd --service=myservice --add-port=12345/tcp --permanent
```

### Port Management
```bash
# Open a port
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent

# Remove a port
sudo firewall-cmd --zone=public --remove-port=8080/tcp --permanent

# Check if a port is open
sudo firewall-cmd --zone=public --query-port=8080/tcp
```

### Rich Rules
```bash
# Block all traffic from an IP
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="1.2.3.4" reject' --permanent

# Allow specific IP to access a port
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.10" port port=22 protocol=tcp accept' --permanent

# Rate limit connections to a service
sudo firewall-cmd --zone=public --add-rich-rule='rule service name="http" limit value="10/m" accept' --permanent

# Limit connections by IP to specific port
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port=22 protocol=tcp limit value="3/m" accept' --permanent

# Log and drop traffic matching specific criteria
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" service name="http" log prefix="HTTP_DROP: " level="info" limit value="3/m" drop' --permanent
```

### IP Sets
```bash
# Create a new ipset
sudo firewall-cmd --permanent --new-ipset=blocklist --type=hash:ip

# Add IPs to the ipset
sudo firewall-cmd --permanent --ipset=blocklist --add-entry=1.2.3.4

# Block all traffic from IPs in an ipset
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule source ipset=blocklist drop'

# Create an ipset from a file
sudo firewall-cmd --permanent --new-ipset=malicious --type=hash:ip
sudo firewall-cmd --permanent --ipset=malicious --add-entries-from-file=/path/to/bad-ips.txt
```

### Direct Rules (for advanced usage)
```bash
# Add a custom iptables rule
sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 0 -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH

# Add a rule to limit SSH connections
sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 1 -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH --rttl -j DROP
```

### Port Forwarding
```bash
# Forward external port to internal host
sudo firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080:toaddr=192.168.1.10 --permanent
```

### Masquerading (NAT)
```bash
# Enable masquerading for a zone
sudo firewall-cmd --zone=external --add-masquerade --permanent

# Remove masquerading
sudo firewall-cmd --zone=external --remove-masquerade --permanent
```

## Apply Changes
```bash
# Always reload after making permanent changes
sudo firewall-cmd --reload

# Runtime changes (no --permanent flag) take effect immediately but are lost on restart
```

## Creating Custom Zones
```bash
# Create a new zone
sudo firewall-cmd --permanent --new-zone=customzone

# Configure the new zone
sudo firewall-cmd --permanent --zone=customzone --set-target=DROP
sudo firewall-cmd --permanent --zone=customzone --add-service=ssh

# After configuring, reload firewalld
sudo firewall-cmd --reload
```

## Security Hardening Techniques

### Anti-Port Scanning
```bash
# Install and set up port-knocking
sudo dnf install knockd

# Rate-limit connection attempts 
sudo firewall-cmd --add-rich-rule='rule service name="ssh" limit value="3/m" accept' --permanent

# Drop invalid packets
sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 0 -m state --state INVALID -j DROP --permanent
```

### Logging
```bash
# Log dropped packets
sudo firewall-cmd --set-log-denied=all --permanent

# Log specific traffic before dropping
sudo firewall-cmd --add-rich-rule='rule service name="ssh" source address="10.0.0.0/8" log prefix="SSH_OUTSIDE_NETWORK: " level="warning" limit value="3/m" drop' --permanent
```

### Panic Mode
```bash
# Enable panic mode (drops all incoming/outgoing packets)
sudo firewall-cmd --panic-on

# Disable panic mode
sudo firewall-cmd --panic-off

# Check if panic mode is enabled
sudo firewall-cmd --query-panic
```

## Creating a Public Network Profile for "Zero Trust"

### Create the profile
```bash
# Create a new zone for public networks
sudo firewall-cmd --permanent --new-zone=zerotrust

# Set very restrictive defaults
sudo firewall-cmd --permanent --zone=zerotrust --set-target=DROP

# Only allow essential outbound traffic
sudo firewall-cmd --permanent --zone=zerotrust --add-service=dns
sudo firewall-cmd --permanent --zone=zerotrust --add-service=https

# Block all incoming connections
# (No need to add any allow rules for incoming)

# Apply the profile to your interface when on public networks
sudo firewall-cmd --zone=zerotrust --change-interface=wlp3s0 --permanent
```

## Custom Scripts

### Script to quickly switch to Zero Trust mode
```bash
#!/bin/bash
# Save as ~/bin/zerotrust-mode.sh
# chmod +x ~/bin/zerotrust-mode.sh

INTERFACE=$(ip route | grep default | awk '{print $5}')
sudo firewall-cmd --zone=zerotrust --change-interface=$INTERFACE
echo "Zero Trust mode ENABLED on $INTERFACE"
echo "Run 'sudo firewall-cmd --zone=home --change-interface=$INTERFACE' to revert"
```

### Script to check for suspicious connections
```bash
#!/bin/bash
# Save as ~/bin/check-connections.sh
# chmod +x ~/bin/check-connections.sh

echo "=== Established Connections ==="
ss -tunapl | grep ESTAB

echo -e "\n=== Listening Services ==="
ss -tulpn | grep LISTEN

echo -e "\n=== Recent Connection Attempts ==="
sudo journalctl -u firewalld --since "10 minutes ago" | grep -E 'REJECT|DROP'
```
