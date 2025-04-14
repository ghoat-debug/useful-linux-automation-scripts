# 🔥 FirewallD Cheatsheet for DevSecOps on Fedora 41

## 🧰 BASIC COMMANDS

### Get Current Status
```bash
# Check if firewalld is running
sudo systemctl status firewalld

# View current default zone
sudo firewall-cmd --get-default-zone

# List all active zones with their interfaces
sudo firewall-cmd --get-active-zones

# Show everything allowed in a zone
sudo firewall-cmd --zone=FedoraWorkstation --list-all

# List all available zones
sudo firewall-cmd --get-zones
```

### Zone Management
```bash
# Change default zone
sudo firewall-cmd --set-default-zone=fortress

# Change which zone an interface uses
sudo firewall-cmd --zone=FedoraWorkstation --change-interface=wlo1

# Create new zone (permanent)
sudo firewall-cmd --permanent --new-zone=customzone
sudo firewall-cmd --reload
```

### Rule Application: Temporary vs Permanent
```bash
# Add temporary rule (gone after reload/reboot)
sudo firewall-cmd --zone=FedoraWorkstation --add-port=8080/tcp

# Add permanent rule (persists after reload/reboot)
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-port=8080/tcp
sudo firewall-cmd --reload  # Apply permanent changes

# Remove a rule
sudo firewall-cmd --permanent --zone=FedoraWorkstation --remove-port=8080/tcp
sudo firewall-cmd --reload
```

## 👩‍💻 DEVSECOPS COMMON USE CASES

### Allow Local Development Services
```bash
# Allow web development ports temporarily
sudo firewall-cmd --zone=FedoraWorkstation --add-port=3000/tcp  # React
sudo firewall-cmd --zone=FedoraWorkstation --add-port=8080/tcp  # Generic web dev
sudo firewall-cmd --zone=FedoraWorkstation --add-port=27017/tcp # MongoDB
sudo firewall-cmd --zone=FedoraWorkstation --add-port=5432/tcp  # PostgreSQL

# Make these available to ONLY localhost (secure dev)
sudo firewall-cmd --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" port port="3000" protocol="tcp" accept'
sudo firewall-cmd --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" source address="127.0.0.1/8" port port="8080" protocol="tcp" accept'
```

### Docker Container Access
```bash
# Allow incoming connections to a specific Docker container port
sudo firewall-cmd --zone=FedoraWorkstation --add-port=8888/tcp

# For actual Docker networking (Fedora already has a docker zone)
sudo firewall-cmd --zone=docker --list-all
```

### Services for Testing/Demos
```bash
# Temporarily allow SSH for demo
sudo firewall-cmd --zone=FedoraWorkstation --add-service=ssh

# Add multiple services at once
sudo firewall-cmd --zone=FedoraWorkstation --add-service={http,https}

# Allow service for specific source IP only (demo to colleague)
sudo firewall-cmd --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" source address="192.168.1.10" service name="ssh" accept'
```

## 🔒 ADVANCED SECURITY RULES

### Port Scan Detection & Prevention
```bash
# Log and drop Xmas scan attempts
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" tcp flags="fin,psh,urg" flags-mask="fin,psh,urg" log prefix="XMAS_SCAN_DROP: " level="warning" limit value="5/m" drop'

# Drop all port scans attempting to use the FIN flag only
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" tcp flags="fin" flags-mask="fin,syn,rst,psh,ack,urg" drop'
```

### Rate Limiting to Prevent DoS
```bash
# Limit incoming pings
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule protocol value="icmp" limit value="5/s" accept'

# Rate limit new TCP connections (SYN packets)
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" tcp flags="syn" limit value="15/s" accept'
```

### Connection Tracking for Smart Filtering
```bash
# Allow established and related connections
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" ct state="RELATED,ESTABLISHED" accept'

# Drop invalid packets
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule family="ipv4" ct state="INVALID" drop'
```

### Geolocation Blocking (requires ipset)
```bash
# Block entire country ranges (example uses ipset)
# First install ipset: sudo dnf install ipset
sudo firewall-cmd --permanent --new-ipset=blocklist --type=hash:net --option=family=inet
sudo firewall-cmd --permanent --ipset=blocklist --add-entry=1.2.3.0/24
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-rich-rule='rule source ipset=blocklist drop'
sudo firewall-cmd --reload
```

## 🔍 LOGGING & DEBUGGING

### View Firewall Logs
```bash
# View rejected packets in real-time
sudo journalctl -f | grep -E '_(DROP|REJECT): '

# Count rejections by source IP
sudo journalctl | grep "REJECT" | awk '{print $13}' | sort | uniq -c | sort -nr | head -10

# Set log verbosity (all, unicast, broadcast, multicast, off)
sudo firewall-cmd --set-log-denied=all
```

### Troubleshooting Commands
```bash
# Test if a port is being blocked
sudo nmap -p 8080 localhost

# Check if a service is correctly configured in firewalld
sudo firewall-cmd --info-service=http

# Debug rich rules
sudo firewall-cmd --debug=2 --direct --add-rule...
```

## 🧩 WORKING WITH CUSTOM SERVICES

### Create Custom Service
```bash
# Create service definition for your app
sudo firewall-cmd --permanent --new-service=myapp
sudo firewall-cmd --permanent --service=myapp --set-description="My Custom App"
sudo firewall-cmd --permanent --service=myapp --add-port=9000/tcp
sudo firewall-cmd --reload

# Then use it
sudo firewall-cmd --zone=FedoraWorkstation --add-service=myapp
```

### Docker Integration
```bash
# Allow traffic to Docker subnet
sudo firewall-cmd --permanent --zone=trusted --add-source=172.17.0.0/16

# For docker compose with custom networks
sudo firewall-cmd --permanent --zone=trusted --add-source=172.18.0.0/16
```

## 📊 Monitoring & Verification

### Check Current Connections
```bash
# View active connections through the firewall
sudo ss -tunap

# Get stats on firewall activity
sudo firewall-cmd --get-log-denied
```

### Scan Your Own Machine
```bash
# Install nmap if not present
sudo dnf install nmap

# Scan all ports from outside perspective
sudo nmap -p- localhost

# Check what services are actually visible
sudo nmap -sV localhost
```

## 🔁 AUTOMATE FIREWALL CHANGES

### Helpful One-Liners
```bash
# Allow a port on trusted networks/block on untrusted (use in scripts)
[ "$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)" == "HomeNetwork" ] && sudo firewall-cmd --add-port=8080/tcp || sudo firewall-cmd --remove-port=8080/tcp

# Reset to default state
sudo systemctl restart firewalld
```

### Restore from Backup
```bash
# Copy backup files back
sudo cp -a /root/firewalld-backup-YYYYMMDD-HHMMSS/* /etc/firewalld/
sudo firewall-cmd --reload
```

## ⚠️ SECURITY TIPS

1. **Default-deny approach**: Start by rejecting everything, then carefully allow only what you need.
2. **Use localhost bindings**: Bind development services to 127.0.0.1 when possible instead of 0.0.0.0.
3. **Regular audits**: Periodically run `sudo firewall-cmd --list-all-zones` to check what's open.
4. **Port exposures**: Consider temporary rules (`--add-port` without `--permanent`) for one-time testing.
5. **Test your firewall**: Use nmap to verify your rules are working as expected.
6. **Always reload**: Remember that `--permanent` options require a reload to take effect.
7. **Monitor logs**: Check firewall logs regularly for unusual activity.

# Temporarily open a port (4 hour timeout)
```sudo firewall-cmd --zone=FedoraWorkstation --add-port=8080/tcp --timeout=14400```

# View all active rules
```
sudo firewall-cmd --list-all-zones
```

# Monitor firewall logs
```
sudo journalctl -u firewalld -f | grep -E 'DROP|REJECT'
```