# ============================================================
#   ____            _      _        _
#  |  _ \  ___  ___| |    (_)_ __  | |__   _____  __
#  | | | |/ _ \/ __| |    | | '_ \ | '_ \ / _ \ \/ /
#  | |_| |  __/\__ \ |____| | | | || |_) | (_) >  <
#  |____/ \___||___/_____|_|_| |_(_)_.__/ \___/_/\_\
#
#  Makondoo's .bashrc — AlmaLinux/RHEL/Fedora Edition
#  "Fedora at heart, Enterprise in production"
#  SELinux is not your enemy. Skill issue.
#  LotL: if it didn't ship with the OS, we probably don't need it.
# ============================================================

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# PATH setup
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# ============================================================
# COLORS
# IMPORTANT — two sets:
#   PS1-safe (use directly in PS1 string):       \[ \]
#   Subshell-safe (use in functions called by $() in PS1): \001 \002
# Mixing these is what kills your cursor. Don't.
# ============================================================
RED='\[\e[0;31m\]'
LRED='\[\e[1;31m\]'
GREEN='\[\e[0;32m\]'
LGREEN='\[\e[1;32m\]'
YELLOW='\[\e[1;33m\]'
PURPLE='\[\e[0;35m\]'
CYAN='\[\e[0;36m\]'
LCYAN='\[\e[1;36m\]'
WHITE='\[\e[1;37m\]'
RESET='\[\e[0m\]'

# Subshell-safe equivalents (RL_PROMPT_START/END_IGNORE)
_RED=$'\001\e[0;31m\002'
_LRED=$'\001\e[1;31m\002'
_GREEN=$'\001\e[0;32m\002'
_LGREEN=$'\001\e[1;32m\002'
_YELLOW=$'\001\e[1;33m\002'
_PURPLE=$'\001\e[0;35m\002'
_LCYAN=$'\001\e[1;36m\002'
_WHITE=$'\001\e[1;37m\002'
_RESET=$'\001\e[0m\002'

# ============================================================
# PROMPT
# ============================================================
parse_git_branch() {
    git branch 2>/dev/null | grep '\*' | sed 's/\* //'
}

# Uses subshell-safe vars — this is the cursor fix
selinux_status() {
    local s
    s=$(getenforce 2>/dev/null) || { echo ""; return; }
    case "$s" in
        Enforcing)  printf '%s' "${_GREEN}[SEL:ON]${_RESET}"    ;;
        Permissive) printf '%s' "${_YELLOW}[SEL:PERM]${_RESET}" ;;
        Disabled)   printf '%s' "${_RED}[SEL:OFF]${_RESET}"     ;;
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

    local sel_part
    sel_part=" $(selinux_status)"

    PS1="\n${user_color}\u${RESET}${WHITE}@${RESET}${LCYAN}\h${RESET}${sel_part} ${YELLOW}\w${RESET}${git_part}\n${status_icon} ${WHITE}\$${RESET} "
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

sel-allow() {
    ausearch -c "$1" --raw | audit2allow -M "$1" && semodule -i "$1".pp && echo "Module '$1' loaded"
}

# ============================================================
# NETWORK
# ============================================================
alias myip4='curl -s https://api4.ipify.org && echo'
alias myip6='curl -s https://api6.ipify.org && echo'
alias myips='echo "IPv4: $(curl -s https://api4.ipify.org)"; echo "IPv6: $(curl -s https://api6.ipify.org)"'
alias ports='ss -tulnp'
alias listening='ss -tlnp'
alias conns='ss -s'
alias ip6='ip -6 addr show'
alias routes6='ip -6 route show'
alias routes='ip route show'
alias fw='firewall-cmd --list-all'
alias fw-reload='firewall-cmd --reload'
alias fw-zones='firewall-cmd --list-all-zones'
alias arp-table='ip neigh show'

# Banner grab using only bash /dev/tcp — no netcat/nmap needed
tcpgrab() {
    # usage: tcpgrab <host> <port>
    exec 3<>/dev/tcp/"$1"/"$2"
    cat <&3
    exec 3>&-
}

# Port check via bash builtins only
portopen() {
    # usage: portopen <host> <port>
    (echo >/dev/tcp/"$1"/"$2") &>/dev/null && echo "OPEN" || echo "CLOSED"
}

# Plain HTTP GET via /dev/tcp — no curl needed
httpget() {
    # usage: httpget <host> [/path]
    local host="$1" path="${2:-/}"
    exec 3<>/dev/tcp/"$host"/80
    printf 'GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n' "$path" "$host" >&3
    cat <&3
    exec 3>&-
}

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
alias cpu='top -bn1 | grep "Cpu(s)"'
alias top='htop 2>/dev/null || top'
alias psa='ps auxf'
alias psg='ps aux | grep -v grep | grep'

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
alias dclean='docker system prune -af --volumes'
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
# Everything below uses only tools from base RHEL/AlmaLinux.
# External deps are flagged with [DEP: pkg].
# ============================================================

# Who is logged in and what happened recently
whoshere() {
    echo "=== Logged in ==="
    who
    echo ""
    echo "=== Last 10 logins ==="
    last -n 10
    echo ""
    echo "=== Failed logins (last 10) ==="
    lastb -n 10 2>/dev/null || journalctl _COMM=sshd -n 20 --no-pager | grep -i fail
}

# Full process tree with user context
proctree() {
    ps -eo user,pid,ppid,pcpu,pmem,stat,comm,args --forest | less
}

# Listening sockets + /proc/net/tcp parsed without ss
listeners() {
    echo "=== ss -tulnp ==="
    ss -tulnp
    echo ""
    echo "=== /proc/net/tcp (local ports, decimal) ==="
    awk 'NR>1 {
        split($2,a,":"); port=strtonum("0x"a[2])
        printf "  :%d  state:%s\n", port, $4
    }' /proc/net/tcp | sort -t: -k2 -n | uniq
}

# Non-zero capabilities on processes — spot privilege escalation candidates
caps() {
    echo "=== Processes with non-zero effective capabilities ==="
    awk '/^Name:/{name=$2} /^CapEff:/{if ($2!="0000000000000000") print name": "$2}' \
        /proc/*/status 2>/dev/null
}

# SUID/SGID — classic LotL recon
suids() {
    echo "=== SUID ==="
    find / -perm -4000 -type f 2>/dev/null | sort
    echo ""
    echo "=== SGID ==="
    find / -perm -2000 -type f 2>/dev/null | sort
}

# World-writable files (excluding /proc /sys /tmp)
worldwrite() {
    find / -not -path '/proc/*' -not -path '/sys/*' -not -path '/tmp/*' \
        -perm -0002 -type f 2>/dev/null | sort
}

# All cron jobs system-wide
croncheck() {
    echo "=== /etc/crontab ==="
    cat /etc/crontab 2>/dev/null
    echo ""
    echo "=== /etc/cron.d/ ==="
    ls -la /etc/cron.d/ 2>/dev/null && cat /etc/cron.d/* 2>/dev/null
    echo ""
    echo "=== User crontabs ==="
    for user in $(cut -f1 -d: /etc/passwd); do
        crontab -u "$user" -l 2>/dev/null | grep -v '^#' | grep -v '^$' \
            && echo "  ^-- $user"
    done
}

# Systemd timers (the cron nobody audits)
timers() {
    systemctl list-timers --all --no-pager
}

# Path and env hygiene check
envcheck() {
    echo "=== PATH entries ==="
    echo "$PATH" | tr ':' '\n'
    echo ""
    echo "=== Writable PATH dirs (privesc risk) ==="
    echo "$PATH" | tr ':' '\n' | while read -r d; do
        [ -w "$d" ] && echo "  WRITABLE: $d"
    done
    echo ""
    echo "=== Sensitive env vars ==="
    env | grep -iE 'pass|token|secret|key|api|aws|auth|cred' 2>/dev/null
}

# Sudoers full dump
sudocheck() {
    echo "=== /etc/sudoers ==="
    cat /etc/sudoers 2>/dev/null
    echo ""
    echo "=== /etc/sudoers.d/ ==="
    cat /etc/sudoers.d/* 2>/dev/null
    echo ""
    echo "=== sudo -l ==="
    sudo -l 2>/dev/null
}

# RPM file integrity — find binaries modified since install [DEP: rpm]
rpmcheck() {
    echo "=== Files modified since RPM install ==="
    rpm -Va 2>/dev/null | grep -v '^......G'
}

# Config drift in /etc vs RPM baseline
etcdrift() {
    echo "=== Modified /etc files vs RPM baseline ==="
    rpm -Va 2>/dev/null | grep '^.M' | awk '{print $NF}' | grep '^/etc'
}

# SSH audit — keys, config, agent sockets
sshaudit() {
    echo "=== sshd_config (active lines) ==="
    grep -v '^\s*#' /etc/ssh/sshd_config 2>/dev/null | grep -v '^$'
    echo ""
    echo "=== Authorized keys ==="
    for h in /home/* /root; do
        local k="$h/.ssh/authorized_keys"
        [ -f "$k" ] && echo "--- $k ---" && cat "$k"
    done
    echo ""
    echo "=== SSH agent sockets ==="
    find /tmp /run -name 'agent.*' -o -name 'ssh-*' 2>/dev/null | head -20
}

# Files modified within last N minutes (default 10)
recent() {
    local mins="${1:-10}"
    find / -not -path '/proc/*' -not -path '/sys/*' -not -path '/run/*' \
        -mmin -"$mins" -type f 2>/dev/null | sort
}

# Deep inspect a pid via /proc — no lsof needed
pidinspect() {
    # usage: pidinspect <pid>
    local pid="$1"
    echo "=== cmdline ==="
    tr '\0' ' ' < /proc/"$pid"/cmdline; echo
    echo ""
    echo "=== environ (secrets filtered) ==="
    tr '\0' '\n' < /proc/"$pid"/environ 2>/dev/null \
        | grep -viE 'pass|token|secret|key' || echo "(access denied)"
    echo ""
    echo "=== open file descriptors ==="
    ls -la /proc/"$pid"/fd 2>/dev/null || echo "(access denied)"
    echo ""
    echo "=== loaded libs ==="
    awk '{print $6}' /proc/"$pid"/maps 2>/dev/null | grep '\.so' | sort -u \
        || echo "(access denied)"
}

# Read /proc/net/tcp without ss or netstat — pure bash
readtcp() {
    printf '%-6s %-22s %-22s %-12s\n' "Proto" "Local" "Remote" "State"
    local states=([1]=ESTABLISHED [2]=SYN_SENT [3]=SYN_RECV [4]=FIN_WAIT1 \
                  [5]=FIN_WAIT2 [6]=TIME_WAIT [7]=CLOSE [8]=CLOSE_WAIT \
                  [9]=LAST_ACK [10]=LISTEN [11]=CLOSING)
    awk 'NR>1 {print $2,$3,$4}' /proc/net/tcp | while read -r loc rem st; do
        local lh lp rh rp
        IFS=: read -r lh lp <<< "$loc"
        IFS=: read -r rh rp <<< "$rem"
        # convert hex IP to dotted decimal
        lh=$(printf '%d.%d.%d.%d' 0x${lh:6:2} 0x${lh:4:2} 0x${lh:2:2} 0x${lh:0:2})
        rh=$(printf '%d.%d.%d.%d' 0x${rh:6:2} 0x${rh:4:2} 0x${rh:2:2} 0x${rh:0:2})
        lp=$((16#$lp)); rp=$((16#$rp))
        state=${states[$((16#$st))]:-UNKNOWN}
        printf 'tcp    %-22s %-22s %-12s\n' "$lh:$lp" "$rh:$rp" "$state"
    done
}

# Bash history across all user accounts
histdump() {
    for h in /home/* /root; do
        local hist="$h/.bash_history"
        [ -f "$hist" ] && echo "=== $hist ===" && cat "$hist" && echo ""
    done
}

# Transfer a file over raw TCP using /dev/tcp — no scp/nc needed
# Receiver end: cat > file.out < /dev/tcp/0.0.0.0/PORT  (or: nc -l PORT > file)
tcpsend() {
    # usage: tcpsend <file> <host> <port>
    cat "$1" > /dev/tcp/"$2"/"$3"
}

# Base64 encode file to stdout for copy-paste transfer
b64out() { base64 "$1"; }
b64in()  { base64 -d > "$1"; }   # usage: b64in outfile.bin  (pipe b64 to stdin)

# Serve current dir over HTTP — python3 or python2 [DEP: python3 or python2]
serve() {
    local port="${1:-8080}"
    if command -v python3 &>/dev/null; then
        python3 -m http.server "$port"
    elif command -v python2 &>/dev/null; then
        python2 -m SimpleHTTPServer "$port"
    else
        echo "No python. Use: cat file > /dev/tcp/host/port"
    fi
}

# ============================================================
# GENERAL UTILITY FUNCTIONS
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
            *)          echo "'$1' — unknown format" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

mkcd()     { mkdir -p "$1" && cd "$1" || return; }
bak()      { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)" && echo "Backup: $1.bak.*"; }
genpass()  { tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c "${1:-32}"; echo; }
hashfile() { sha256sum "${1:--}"; }
reload()   { source ~/.bashrc && echo ".bashrc reloaded"; }
tlog()     { tail -f "$1" | grep --line-buffered -E 'error|warn|crit|fail|deny|AVC' --color=auto; }

# Who is hammering the server
bashers() {
    ss -ntu | awk 'NR>1 {print $6}' | cut -d: -f1 | grep -v '^$' \
        | sort | uniq -c | sort -nr | head -20
}

# Grep recursively through config/script files for sensitive patterns
findin() {
    # usage: findin <pattern> [dir]
    grep -rn --include='*.conf' --include='*.cfg' --include='*.env' \
        --include='*.yml' --include='*.yaml' --include='*.json' \
        --include='*.sh' --include='*.py' \
        "$1" "${2:-.}" 2>/dev/null
}

# ============================================================
# MOTD — reads from /proc where possible, no external deps
# ============================================================
if [[ $- == *i* ]]; then
    echo -e ""
    echo -e "  \e[1;36m$(hostname)\e[0m | \e[1;33m$(uname -r)\e[0m | \e[1;32m$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')\e[0m"
    echo -e "  Uptime: \e[1;37m$(uptime -p)\e[0m"
    echo -e "  Load:   \e[1;37m$(awk '{print $1,$2,$3}' /proc/loadavg)\e[0m"
    echo -e "  Memory: \e[1;37m$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%dM used / %dM total",(t-a)/1024,t/1024}' /proc/meminfo)\e[0m"
    echo -e "  Disk:   \e[1;37m$(df -h / | awk 'NR==2{print $3" used / "$2" ("$5")"}')\e[0m"
    echo -e "  SELinux:\e[1;37m $(getenforce 2>/dev/null || echo 'not found')\e[0m"
    echo -e "  IPv4:   \e[1;37m$(ip -4 addr show scope global | awk '/inet /{print $2}' | head -1)\e[0m"
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

# ============================================================
# QOL
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

# NVM (if present)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]            && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ]   && \. "$NVM_DIR/bash_completion"

# ============================================================
# Done.
# ============================================================
