# FirewallD Cheatsheet for DevSecOps

## 🔍 Basic Commands

### Zone Management
```bash
# List all available zones
firewall-cmd --get-zones

# Get default zone
firewall-cmd --get-default-zone

# Set default zone
firewall-cmd --set-default-zone=<zone-name>

# Get active zones
firewall-cmd --get-active-zones

# Get details of a specific zone
firewall-cmd --zone=<zone-name> --list-all
```

### Service Management
```bash
# List all predefined services
firewall-cmd --get-services

# Allow a service in the default zone
firewall-cmd --permanent --add-service=<service-name>

# Remove a service from the default zone
firewall-cmd --permanent --remove-service=<service-name>

# Check if a service is allowed
firewall-cmd --query-service=<service-name>
```

### Port Management
```bash
# Open a port in the default zone
firewall-cmd --permanent --add-port=<port-number>/<protocol>

# Close a port in the default zone
firewall-cmd --permanent --remove-port=<port-number>/<protocol>

# Check if a port is open
firewall-cmd --query-port=<port-number>/<protocol>
```

### Apply Changes
```bash
# Reload firewall to apply changes
firewall-cmd --reload

# Runtime vs permanent rules
# Add --permanent to make changes persist after reload/reboot
```

## 🛡️ Advanced Security

### Rich Rules
```bash
# Basic rich rule syntax
firewall-cmd --permanent --add-rich-rule='<rule>'

# Example: Allow SSH only from specific IP
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.10" service name="ssh" accept'

# Example: Rate limit connections to port 80
firewall-cmd --permanent --add-rich-rule='rule service name="http" limit value="10/m" accept'

# Example: Log and drop traffic
firewall-cmd --permanent --add-rich-rule='rule service name="http" log prefix="HTTP_DROP: " level="warning" limit value="5/m" drop'
```

### Connection Tracking
```bash
# Accept established connections
firewall-cmd --permanent --add-rich-rule='rule ct state RELATED,ESTABLISHED accept'

# Drop invalid packets
firewall-cmd --permanent --add-rich-rule='rule ct state INVALID drop'
```

### Port Scan Protection
```bash
# Block SYN-FIN scans
firewall-cmd --permanent --add-rich-rule='rule tcp flags="SYN,FIN" drop'

# Block Xmas scans
firewall-cmd --permanent --add-rich-rule='rule tcp flags="FIN,SYN,RST,PSH,ACK,URG" tcp-flags="FIN,SYN,RST,PSH,ACK,URG" drop'

# Block null scans
firewall-cmd --permanent --add-rich-rule='rule tcp flags="FIN,SYN,RST,PSH,ACK,URG" tcp-flags="NONE" drop'
```

### IPv6 Security
```bash
# Block IPv6 router advertisements (if not needed)
firewall-cmd --permanent --add-rich-rule='rule family="ipv6" icmp-type name="router-advertisement" drop'

# Allow only specific IPv6 ICMP types
firewall-cmd --permanent --add-rich-rule='rule family="ipv6" protocol value="ipv6-icmp" icmp-type name="echo-request" accept'
```

## 💼 DevSecOps Specific

### Docker Integration
```bash
# Check if docker zone exists
firewall-cmd --get-zones | grep docker

# Allow specific ports in docker zone
firewall-cmd --permanent --zone=docker --add-port=<port>/<protocol>

# Add interface to docker zone
firewall-cmd --permanent --zone=docker --add-interface=<interface>
```

### Local Development
```bash
# Allow localhost access to all services
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv6" source address="::1" accept'

# Allow only localhost to access development port
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source NOT address="127.0.0.1" port port="8080" protocol="tcp" drop'
```

### Pentesting Setup
```bash
# Allow outgoing connections on common pentest ports
firewall-cmd --permanent --zone=<zone> --add-rich-rule='rule port port="443" protocol="tcp" outbound accept'
firewall-cmd --permanent --zone=<zone> --add-rich-rule='rule port port="8080" protocol="tcp" outbound accept'

# Forward a port for specific tools
firewall-cmd --permanent --add-forward-port=port=<port>:proto=<protocol>:toport=<target-port>
```

## 🔐 Zero Trust Model

### Network Segmentation
```bash
# Allow specific interface to specific zone
firewall-cmd --permanent --zone=<zone> --add-interface=<interface>

# Allow specific source to specific zone
firewall-cmd --permanent --zone=<zone> --add-source=<ip-address/subnet>
```

### Logging & Auditing
```bash
# Enable logging for specific service
firewall-cmd --permanent --add-rich-rule='rule service name="<service>" log prefix="<SERVICE>_ACCESS: " level="notice" limit value="3/m" accept'

# Log dropped packets
firewall-cmd --permanent --add-rich-rule='rule log prefix="DROP_PACKET: " level="warning" limit value="10/m" drop'
```

### Emergency Lockdown
```bash
# Switch to drop-all mode in emergency
firewall-cmd --panic-on

# Disable panic mode
firewall-cmd --panic-off

# Check if in panic mode
firewall-cmd --query-panic
```

## 🔄 Best Practices

1. **Always test changes** before applying permanently
2. **Use `--timeout` option** for temporary changes
3. **Keep backup** of your firewall configuration
4. **Use descriptive log prefixes** for easier analysis
5. **Implement rate limiting** to prevent DoS attacks
6. **Use zones** to segment different networks
7. **Apply principle of least privilege** - only open what's needed
8. **Regularly audit** your firewall rules
9. **Use connection tracking** for stateful filtering
10. **Document your rule set** and reasons for each rule

## 📊 Troubleshooting

```bash
# Get debug logs
journalctl -u firewalld

# Check if firewalld is running
systemctl status firewalld

# Test a rule before applying
firewall-cmd --add-rich-rule='<rule>' --timeout=60

# Backup configuration
cp -r /etc/firewalld /etc/firewalld.bak

# Restore configuration
cp -r /etc/firewalld.bak /etc/firewalld
systemctl restart firewalld
```
