# useful-linux-automation-scripts
this repo is for some of the automation scripts for normal linux use for various uses
helps save time, especially for new installs when you have a specific configuration and theme combo you like.
get it have a copy and install when needed.


# 🔥 MAKONDOO Security Toolbox 🔥

![Makondoo Inc.](https://via.placeholder.com/800x200?text=MAKONDOO+SECURITY+TOOLBOX)

## 🚀 What's This?

**A DevSecOps powerhouse for your terminal.** This repo contains battle-tested configurations and scripts to boost your security posture on Fedora and other Linux distros.

Designed with the modern tech bro in mind - because security should be dope, not dull.

[![GitHub stars](https://img.shields.io/github/stars/yourusername/makondoo-security-toolbox?style=social)](https://github.com/yourusername/makondoo-security-toolbox)
[![Security Rating](https://img.shields.io/badge/Security-Hardcore-red)](https://github.com/yourusername/makondoo-security-toolbox)
[![Vibe Check](https://img.shields.io/badge/Vibe-Immaculate-blueviolet)](https://github.com/yourusername/makondoo-security-toolbox)

---

## 📂 Current Projects

### /firewalld
Next-level firewalld configurations for the security conscious:

- **running-firewall-setup.sh**: Enhanced firewall configuration that prevents port scanning and creates a fortress mode for public networks.
- **running-autonetwork-switcher.sh**: Auto-switching between normal and fortress security based on your network. No cap - it just works.
- **help.md**: Comprehensive cheatsheet for firewalld operations that'll make you the alpha of your security team.

---

## ⚡ Quick Start

No long tutorials - let's get this bread:

```bash
# Clone this repo
git clone https://github.com/yourusername/makondoo-security-toolbox.git

# Navigate to firewalld directory
cd makondoo-security-toolbox/firewalld

# Make scripts executable
chmod +x running-firewall-setup.sh running-autonetwork-switcher.sh

# Set up your enhanced firewall (sudo required)
sudo ./running-firewall-setup.sh

# Set up automatic network security switching
sudo ./running-autonetwork-switcher.sh --setup-service

# Add your trusted networks
sudo ./running-autonetwork-switcher.sh --add "YourHomeWiFi"
sudo ./running-autonetwork-switcher.sh --add "YourWorkWiFi" 
```

---

## 🔍 Features

### Enhanced Firewall Setup
- **Port scan shielding** - They can't hack what they can't see
- **Anti-reconnaissance measures** - Blocks various scan techniques 
- **Local-only services** - Your dev environment stays yours
- **Zero Trust mode** for public networks - Trust nothing, secure everything

### Auto Network Switcher
- **Context-aware security** that adapts to your location
- **Automatic fortress mode** activation on sketchy networks
- **Simple trusted network management** with CLI commands
- **Systemd service integration** for set-it-and-forget-it security

---

## 💻 Usage Guide

### Firewall Setup Script
```bash
# Run with sudo to set up your enhanced firewall
sudo ./running-firewall-setup.sh

# Switch to fortress mode manually
sudo firewall-cmd --set-default-zone=fortress

# Switch back to normal mode
sudo firewall-cmd --set-default-zone=FedoraWorkstation
```

### Network Switcher
```bash
# Install as systemd service (recommended)
sudo ./running-autonetwork-switcher.sh --setup-service

# Add a trusted network
sudo ./running-autonetwork-switcher.sh --add "NetworkName"

# Remove a trusted network
sudo ./running-autonetwork-switcher.sh --remove "NetworkName"

# List all trusted networks
sudo ./running-autonetwork-switcher.sh --list

# Check current status
sudo ./running-autonetwork-switcher.sh --status

# Run once to check and update
sudo ./running-autonetwork-switcher.sh

# Run in daemon mode (checks every 30s)
sudo ./running-autonetwork-switcher.sh --daemon
```

### Firewall Cheatsheet
Check out `help.md` for a comprehensive guide to firewalld commands and best practices. Perfect for presentations or when you need a quick reminder.

---

## 🚧 Roadmap

We're just getting started. MAKONDOO Security Toolbox is planning to expand with:

- [ ] More security tools and configurations
- [ ] IDS/IPS setup scripts
- [ ] Container security profiles
- [ ] Cloud security posture monitoring
- [ ] Penetration testing tools and configs
- [ ] Server hardening scripts

---

## 🤝 Contributing

We're building something big, and your input is gold. Here's how to contribute:

1. **Fork the repo** and create a new branch for your contribution
2. **Make your changes** (keep the same vibe and energy)
3. **Test thoroughly** - security tools must work flawlessly
4. **Submit a PR** with a detailed description of your changes
5. **Code review** - we'll check your contribution with respect

### Contribution Guidelines

- **Keep it real**: Security scripts should be practical and useful
- **Document everything**: Your code should be readable and well-commented
- **Test, test, test**: Security tools can't fail when they're needed most
- **Maintain the vibe**: Our tools should be powerful but also have personality
- **No bloat**: Keep scripts efficient and focused

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. Use responsibly.

---

## 🔥 About MAKONDOO Inc.

MAKONDOO Inc. is the future of cybersecurity solutions - building tools that are both powerful and accessible. 

Currently in stealth mode, but watch this space. Big things coming.

---

Made with ☕ and 💻 by the MAKONDOO team
