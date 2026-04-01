# ============================================================
#   ____            _      _        _
#  |  _ \  ___  ___| |    (_)_ __  | |__   _____  __
#  | | | |/ _ \/ __| |    | | '_ \ | '_ \ / _ \ \/ /
#  | |_| |  __/\__ \ |____| | | | || |_) | (_) >  <
#  |____/ \___||___/_____|_|_| |_(_)_.__/ \___/_/\_\
#
#  Makondoo's .bashrc — AlmaLinux Edition 🎩
#  "Fedora at heart, Enterprise in production"
#  SELinux is not your enemy. Skill issue.
#this is the original slow compiled script finally found it in archives and cleaned up with new ol AI like every techie out here
# ============================================================

# --- Source global definitions ---
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# --- PATH setup ---
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# ============================================================
# 🎨 COLORS
# ============================================================
RED='\[\e[0;31m\]'
LRED='\[\e[1;31m\]'
GREEN='\[\e[0;32m\]'
LGREEN='\[\e[1;32m\]'
YELLOW='\[\e[1;33m\]'
BLUE='\[\e[0;34m\]'
LBLUE='\[\e[1;34m\]'
PURPLE='\[\e[0;35m\]'
CYAN='\[\e[0;36m\]'
LCYAN='\[\e[1;36m\]'
WHITE='\[\e[1;37m\]'
RESET='\[\e[0m\]'

# ============================================================
# 🚀 PROMPT — cursor fix + SELinux + git branch + cwd
# ============================================================
# Cursor shape codes (wrapped in \[...\] so readline counts correctly):
#   \[\e[1 q\]  blinking block  (default feel)
#   \[\e[2 q\]  steady block
#   \[\e[3 q\]  blinking underline
#   \[\e[5 q\]  blinking bar  ← good for insert-mode feel
#   \[\e[?25h\] force cursor VISIBLE (un-hides if something killed it)
CURSOR_RESET='\[\e[?25h\e[1 q\]'

parse_git_branch() {
    git branch 2>/dev/null | grep '\*' | sed 's/\* //'
}

selinux_status() {
    local status
    status=$(getenforce 2>/dev/null)
    case "$status" in
        Enforcing)  echo -e "\e[0;32m[SEL:ON]\e[0m" ;;
        Permissive) echo -e "\e[1;33m[SEL:PERM]\e[0m" ;;
        Disabled)   echo -e "\e[0;31m[SEL:OFF]\e[0m" ;;
        *)          echo "" ;;
    esac
}

build_prompt() {
    local exit_code=$?
    local git_branch
    git_branch=$(parse_git_branch)

    local status_icon
    if [ $exit_code -eq 0 ]; then
        status_icon="${LGREEN}[ok]${RESET}"
    else
        status_icon="${LRED}[!!${exit_code}]${RESET}"
    fi

    local git_part=""
    if [ -n "$git_branch" ]; then
        git_part=" ${PURPLE}(${git_branch})${RESET}"
    fi

    local user_color
    if [ "$EUID" -eq 0 ]; then
        user_color="${LRED}"
    else
        user_color="${LGREEN}"
    fi

    # CURSOR_RESET goes at the very end so it applies before each input line
    PS1="\n${user_color}\u${RESET}${WHITE}@${RESET}${LCYAN}\h${RESET} ${YELLOW}\w${RESET}${git_part}\n${status_icon} ${WHITE}\$${RESET} ${CURSOR_RESET}"
}

PROMPT_COMMAND=build_prompt

# ============================================================
# 🗂  NAVIGATION
# ============================================================
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias lt='ls -lahtr --color=auto'
alias lsize='ls -lSh --color=auto'

# ============================================================
# 🛡  SAFETY NETS
# ============================================================
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'

# ============================================================
# 🔒 SELINUX
# ============================================================
alias getstatus='getenforce'
alias sel-on='setenforce 1 && echo "SELinux: Enforcing 💪"'
alias sel-off='setenforce 0 && echo "SELinux: Permissive ⚠  (temporary only, restart will restore)"'
alias sel-log='tail -f /var/log/audit/audit.log | grep AVC'
alias sel-denials='ausearch -m avc -ts recent | audit2why'
alias sel-context='ls -Z'
alias sel-ports='semanage port -l'
alias sel-fix='restorecon -Rv'

# ============================================================
# 🌐 NETWORK
# ============================================================
alias myip4='curl -s https://api4.ipify.org && echo'
alias myip6='curl -s https://api6.ipify.org && echo'
alias myips='echo "IPv4: $(curl -s https://api4.ipify.org)"; echo "IPv6: $(curl -s https://api6.ipify.org)"'
alias ports='ss -tulnp'
alias listening='ss -tlnp'
alias conns='ss -s'
alias ip6='ip -6 addr show'
alias routes6='ip -6 route show'
alias ping6g='ping6 google.com'
alias fw='firewall-cmd --list-all'
alias fw-reload='firewall-cmd --reload'

# ============================================================
# 🖥  SYSTEM
# ============================================================
alias update='dnf update -y'
alias install='dnf install -y'
alias remove='dnf remove -y'
alias search='dnf search'
alias services='systemctl list-units --type=service --state=running'
alias failed='systemctl --failed'
alias logs='journalctl -xe'
alias disk='df -hT | grep -v tmpfs'
alias mem='free -h'
alias cpu='top -bn1 | grep "Cpu(s)"'
alias top='htop 2>/dev/null || top'
alias psa='ps auxf'
alias psg='ps aux | grep -v grep | grep'

# ============================================================
# 🔑 SSH
# ============================================================
alias sshconfig='cat ~/.ssh/config'
alias keygen='ssh-keygen -t ed25519 -C'
alias addkey='ssh-copy-id'

# ============================================================
# 🐳 CONTAINERS
# ============================================================
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dlogs='docker logs -f'
alias dex='docker exec -it'
alias pods='podman ps'
alias podsa='podman ps -a'

# ============================================================
# 📋 GIT
# ============================================================
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch -a'

# ============================================================
# 🪓 LIVING OFF THE LAND
# ============================================================
# Pure bash / standard-unix-only. No exotic tools required.
# These work even when you've got nothing installed.

# --- Enumeration ---

# All users with a real login shell
alias enum-users='grep -vE "nologin|false|sync|halt|shutdown" /etc/passwd | awk -F: "{print \$1,\$3,\$6,\$7}" | column -t'

# SUID binaries — know what's there before an attacker does
alias enum-suid='find / -perm -4000 -type f 2>/dev/null | xargs ls -lah'

# SGID binaries
alias enum-sgid='find / -perm -2000 -type f 2>/dev/null | xargs ls -lah'

# Linux capabilities on binaries (getcap is usually present on RHEL/Alma)
alias enum-caps='getcap -r / 2>/dev/null'

# World-writable files outside /tmp /proc /sys /dev
alias enum-writable='find / -xdev -perm -0002 -type f 2>/dev/null | grep -Ev "^/(proc|sys|dev|tmp|run)"'

# World-writable directories
alias enum-wdirs='find / -xdev -perm -0002 -type d 2>/dev/null | grep -Ev "^/(proc|sys|dev|tmp|run)"'

# All cron jobs across users (requires root for full picture)
alias enum-cron='for u in $(cut -f1 -d: /etc/passwd); do crontab -l -u $u 2>/dev/null | grep -v "^#" | sed "/^$/d" | sed "s/^/$u: /"; done; echo "--- /etc/cron* ---"; ls -lah /etc/cron* 2>/dev/null'

# Sudoers quick view (what can THIS user do)
alias enum-sudo='sudo -l 2>/dev/null'

# Running processes with full paths
alias enum-procs='ps auxf --sort=-%cpu | head -40'

# Network neighbours (ARP table) — useful for lateral movement scope
alias enum-arp='arp -n 2>/dev/null || ip neigh show'

# Listening services with PIDs and owners
alias enum-listen='ss -tulnp'

# Mounted filesystems — spot NFS/CIFS shares, unusual mounts
alias enum-mounts='mount | column -t; echo; cat /proc/mounts | grep -v "^proc\|^sys\|^dev\|^run\|^cgroup\|tmpfs"'

# Environment dump (sorted, no secrets on screen — pipe to grep if needed)
alias enum-env='env | sort'

# Loaded kernel modules
alias enum-mods='lsmod | sort'

# Interesting files in /proc for current process
alias enum-proc-self='ls -lah /proc/self/fd; cat /proc/self/status; cat /proc/self/maps | head -30'

# --- LotL Networking (pure bash /dev/tcp — zero tools needed) ---

# TCP connectivity check without nc/nmap
tcpcheck() {
    # usage: tcpcheck <host> <port>
    (echo >/dev/tcp/"$1"/"$2") &>/dev/null && echo "[+] $1:$2 OPEN" || echo "[-] $1:$2 CLOSED/FILTERED"
}

# HTTP GET via pure bash — no curl/wget
bashget() {
    # usage: bashget <host> <port> <path>
    local host="$1" port="${2:-80}" path="${3:-/}"
    exec 3<>/dev/tcp/"$host"/"$port"
    echo -e "GET $path HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n" >&3
    cat <&3
    exec 3>&-
}

# Port scan a host using /dev/tcp — slow but tool-free
portscan() {
    # usage: portscan <host> [start_port] [end_port]
    local host="$1"
    local start="${2:-1}"
    local end="${3:-1024}"
    echo "[*] Scanning $host ports $start-$end (bash /dev/tcp)"
    for port in $(seq "$start" "$end"); do
        (echo >/dev/tcp/"$host"/"$port") &>/dev/null && echo "  [+] $port/tcp OPEN"
    done
    echo "[*] Done."
}

# --- LotL Data / Encoding ---

# Base64 encode a file or stdin
alias b64enc='base64'
alias b64dec='base64 -d'

# Quick hex dump of a file
alias hexd='xxd'

# Grab a file's sha256 without dedicated tools ambiguity
alias sha='sha256sum'

# In-memory string to hex (no xxd needed)
str2hex() { printf '%s' "$1" | od -A n -t x1 | tr -d ' \n'; echo; }

# Decode a base64 string directly
b64s() { echo "$1" | base64 -d; echo; }

# --- LotL File Operations ---

# Find files modified in last N minutes (default 10) — spot active writes
recent-writes() {
    local mins="${1:-10}"
    find / -xdev -type f -newer /proc/1 -mmin -"$mins" 2>/dev/null \
        | grep -Ev "^/(proc|sys|dev|run)"
}

# Files modified in last 24h under a given path
changed-files() {
    find "${1:-.}" -type f -mtime -1 2>/dev/null | sort
}

# --- LotL Persistence / Forensics ---

# All SSH authorized_keys on the system
alias enum-authkeys='find /home /root -name "authorized_keys" 2>/dev/null -exec echo "=== {} ===" \; -exec cat {} \;'

# Bash history of all users (root required for full sweep)
alias enum-hist='for d in /root /home/*; do [ -f "$d/.bash_history" ] && echo "=== $d ===" && cat "$d/.bash_history"; done'

# Systemd timers — often used for persistence, often forgotten
alias enum-timers='systemctl list-timers --all'

# At jobs
alias enum-at='atq 2>/dev/null'

# Recently installed packages (last 20)
alias enum-installs='rpm -qa --qf "%{installtime:date} %{name}\n" 2>/dev/null | sort -r | head -20'

# Login history
alias enum-logins='last -aF | head -30'

# Failed logins
alias enum-fails='lastb 2>/dev/null | head -20 || journalctl _SYSTEMD_UNIT=sshd.service | grep "Failed" | tail -20'

# Active sessions
alias enum-who='w -hs'

# --- LotL Quick Privesc Checks ---

# Writable files owned by root (potential hijack targets)
alias priv-rootwrite='find / -xdev -user root -perm -0002 -type f 2>/dev/null | grep -Ev "^/(proc|sys|dev|tmp)"'

# Files with no owner (orphaned — useful post-exploitation artefact hunting)
alias priv-noowner='find / -xdev -nouser -o -nogroup 2>/dev/null | grep -Ev "^/(proc|sys|dev)"'

# Readable /etc/shadow check (should NEVER return anything)
alias priv-shadow='ls -lah /etc/shadow && head -3 /etc/shadow 2>/dev/null && echo "[!] shadow readable" || echo "[ok] shadow not readable"'

# Check for common sudo misconfigurations quickly
alias priv-sudo='sudo -l 2>/dev/null | grep -E "NOPASSWD|ALL"'

# ============================================================
# 🛠  HANDY FUNCTIONS
# ============================================================

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)  tar xjf "$1"    ;;
            *.tar.gz)   tar xzf "$1"    ;;
            *.tar.xz)   tar xJf "$1"    ;;
            *.bz2)      bunzip2 "$1"    ;;
            *.rar)      unrar x "$1"    ;;
            *.gz)       gunzip "$1"     ;;
            *.tar)      tar xf "$1"     ;;
            *.tbz2)     tar xjf "$1"    ;;
            *.tgz)      tar xzf "$1"    ;;
            *.zip)      unzip "$1"      ;;
            *.Z)        uncompress "$1" ;;
            *.7z)       7z x "$1"       ;;
            *)          echo "'$1' — I have no idea what this is 🤷" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

mkcd()     { mkdir -p "$1" && cd "$1" || return; }
portcheck(){ nc -zv "$1" "$2" 2>&1; }
bashers()  { netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -20; }
genpass()  { tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c "${1:-32}"; echo; }
tlog()     { tail -f "$1" | grep --line-buffered -E 'error|warn|crit|fail|deny' --color=auto; }
reload()   { source ~/.bashrc && echo "✅ .bashrc reloaded"; }
bak()      { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)" && echo "Backup created: $1.bak.*"; }

openports() {
    echo -e "\n${LGREEN}Open Ports${RESET}"
    echo "-----------------------------------------------"
    ss -tulnp | column -t
}

sel-allow() {
    ausearch -c "$1" --raw | audit2allow -M "$1" && semodule -i "$1".pp && echo "Module '$1' loaded ✅"
}

# ============================================================
# 🎉 MOTD
# ============================================================
if [[ $- == *i* ]]; then
    echo -e ""
    echo -e "  \e[1;36m$(hostname)\e[0m | \e[1;33m$(uname -r)\e[0m | \e[1;32mAlmaLinux\e[0m"
    echo -e "  Uptime: \e[1;37m$(uptime -p)\e[0m"
    echo -e "  Load:   \e[1;37m$(cat /proc/loadavg | awk '{print $1,$2,$3}')\e[0m"
    echo -e "  Memory: \e[1;37m$(free -h | awk '/^Mem:/ {print $3 " used / " $2}')\e[0m"
    echo -e "  Disk:   \e[1;37m$(df -h / | awk 'NR==2 {print $3 " used / " $2 " (" $5 ")"}')\e[0m"
    echo -e "  SELinux:\e[1;37m $(getenforce 2>/dev/null || echo 'not found')\e[0m"
    echo -e "  IPv4:   \e[1;37m$(hostname -I | awk '{print $1}')\e[0m"
    echo -e ""
    echo -e "  \e[0;35m\"In SELinux we trust. The rest we audit.\"\e[0m"
    echo -e ""
fi

# ============================================================
# HISTORY
# ============================================================
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT="%F %T  "
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# ============================================================
# MISC QOL
# ============================================================
export EDITOR=vim
export VISUAL=vim
export PAGER=less
export LESS='-R'
shopt -s checkwinsize
shopt -s cdspell
set -o noclobber
if [[ $- == *i* ]]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

# ============================================================
# 🎩  Done. Welcome to your server, boss.
# ============================================================

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
