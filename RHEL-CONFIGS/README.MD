# dotfiles — Makondoo's `.bashrc`

```
  ____            _      _        _
 |  _ \  ___  ___| |    (_)_ __  | |__   _____  __
 | | | |/ _ \/ __| |    | | '_ \ | '_ \ / _ \ \/ /
 | |_| |  __/\__ \ |____| | | | || |_) | (_) >  <
 |____/ \___||___/_____|_|_| |_(_)_.__/ \___/_/\_\
```

A battle-tested `.bashrc` for **AlmaLinux / RHEL / Fedora** environments. Built around a **living-off-the-land (LotL) philosophy** — the goal is maximum capability using only tools that ship with a base RHEL-family install. No `apt install`, no curl-piping random scripts, no assumptions about what's available beyond the OS defaults.

---

## Compatibility

| Distro | Status |
|---|---|
| AlmaLinux 8 / 9 | ✅ Primary target |
| RHEL 8 / 9 | ✅ |
| Fedora (recent) | ✅ |
| Rocky Linux | ✅ |
| CentOS Stream | ✅ |
| Debian / Ubuntu | ⚠️ Works mostly, SELinux and `dnf` aliases won't apply |

---

## Installation

```bash
# Back up your existing .bashrc first
cp ~/.bashrc ~/.bashrc.bak.$(date +%Y%m%d)

# Drop the new one in
curl -o ~/.bashrc https://raw.githubusercontent.com/ghoat-debug/useful-linux-automation-scripts/refs/heads/main/RHEL-CONFIGS/.bashrc

# Reload
source ~/.bashrc
```

> **Note:** If you're not root, some LotL functions (`suids`, `sudocheck`, `histdump`, etc.) will be read-access limited. Run as root or via `sudo -i` for full output.

---

## Prompt

The prompt shows the following at a glance:

```
[user@hostname] [SEL:ON] ~/path (git-branch)
[ok] $
```

| Element | Meaning |
|---|---|
| Username | Green = normal user, Red = root |
| `[SEL:ON]` | SELinux Enforcing (green) |
| `[SEL:PERM]` | SELinux Permissive (yellow) — investigate |
| `[SEL:OFF]` | SELinux Disabled (red) — fix this |
| Git branch | Shows current branch if inside a repo |
| `[ok]` | Last command exited 0 |
| `[!!N]` | Last command exited with code N |

**Why the cursor works correctly:** Color codes inside functions called via `$()` in `PS1` must use `\001`/`\002` (readline's `RL_PROMPT_START/END_IGNORE`), not `\[`/`\]`. Using `\[`/`\]` inside subshell output causes readline to miscount line length — your cursor position breaks and appears to vanish. This file maintains two separate color variable sets to handle both contexts correctly.

---

## Aliases

### Navigation
| Alias | Command |
|---|---|
| `..` `...` `....` | `cd` up 1 / 2 / 3 levels |
| `ll` | `ls -lah --color=auto` |
| `la` | `ls -A --color=auto` |
| `lt` | `ls -lahtr` — sorted by time, newest last |
| `lsize` | `ls -lSh` — sorted by size |

### Safety nets
| Alias | Behaviour |
|---|---|
| `rm` `cp` `mv` `ln` | Interactive mode — prompts before overwrite/delete |
| `chown` `chmod` `chgrp` | `--preserve-root` on all three |

> `set -o noclobber` is also set — `>` will not silently overwrite existing files. Use `>|` to force.

### SELinux
| Alias | What it does |
|---|---|
| `getstatus` | `getenforce` |
| `sel-on` | `setenforce 1` — back to Enforcing |
| `sel-off` | `setenforce 0` — Permissive (survives until reboot only) |
| `sel-log` | Live tail of AVC denials from audit.log |
| `sel-denials` | Recent AVC denials piped through `audit2why` |
| `sel-context` | `ls -Z` — show file security contexts |
| `sel-ports` | `semanage port -l` — all labelled ports |
| `sel-fix` | `restorecon -Rv` — recursively restore file contexts |

### Network
| Alias | What it does |
|---|---|
| `myip4` / `myip6` | Public IPv4 / IPv6 via ipify |
| `myips` | Both at once |
| `ports` | `ss -tulnp` |
| `listening` | `ss -tlnp` |
| `conns` | `ss -s` — connection summary |
| `routes` | `ip route show` |
| `routes6` | `ip -6 route show` |
| `arp-table` | `ip neigh show` |
| `fw` | `firewall-cmd --list-all` |
| `fw-reload` | `firewall-cmd --reload` |
| `fw-zones` | `firewall-cmd --list-all-zones` |

### System
| Alias | What it does |
|---|---|
| `update` | `dnf update -y` |
| `install` | `dnf install -y` |
| `remove` | `dnf remove -y` |
| `search` | `dnf search` |
| `services` | Running systemd services |
| `failed` | Failed systemd units |
| `logs` | `journalctl -xe` |
| `disk` | `df -hT` (tmpfs filtered) |
| `mem` | `free -h` |
| `psa` | `ps auxf` — full process tree |
| `psg <name>` | `ps aux \| grep <name>` |
| `top` | `htop` if available, falls back to `top` |

### Docker / Podman
| Alias | What it does |
|---|---|
| `dps` / `dpsa` | `docker ps` / `docker ps -a` |
| `dimg` | `docker images` |
| `dlogs` | `docker logs -f` |
| `dex` | `docker exec -it` |
| `dnet` / `dvol` | Network / volume list |
| `dclean` | Full prune — containers, images, volumes |
| `dstats` | Resource snapshot (no stream) |
| `pods` / `podsa` | Podman equivalents |

### Git
| Alias | What it does |
|---|---|
| `gs` | `git status` |
| `ga` | `git add` |
| `gc "msg"` | `git commit -m` |
| `gp` | `git push` |
| `gl` | Log graph — oneline, all branches |
| `gd` | `git diff` |
| `gco` | `git checkout` |
| `gb` | `git branch -a` |

---

## Functions

### General Utility
| Function | Usage | What it does |
|---|---|---|
| `extract <file>` | `extract archive.tar.gz` | Universal archive extractor — handles tar, zip, gz, bz2, xz, 7z, rar, Z |
| `mkcd <dir>` | `mkcd project/src` | `mkdir -p` + `cd` in one |
| `bak <file>` | `bak nginx.conf` | Timestamped backup copy in place |
| `genpass [len]` | `genpass 48` | Random password from `/dev/urandom`, default 32 chars |
| `hashfile [file]` | `hashfile binary` | SHA256 — defaults to stdin if no file given |
| `tlog <file>` | `tlog /var/log/app.log` | `tail -f` with colour highlights for error/warn/fail/deny/AVC |
| `reload` | `reload` | `source ~/.bashrc` |
| `bashers` | `bashers` | Top 20 IPs hammering your server by connection count |
| `findin <pat> [dir]` | `findin password /etc` | Grep for pattern across conf/cfg/env/yml/json/sh/py files |
| `sel-allow <name>` | `sel-allow nginx` | Generates and loads an SELinux module from recent audit denials |

### Living Off the Land — Recon & Enumeration

All functions below use **only tools from a base RHEL/AlmaLinux install**. External deps are flagged explicitly.

| Function | Usage | What it does |
|---|---|---|
| `whoshere` | `whoshere` | Logged-in users, last 10 logins, recent SSH failures |
| `proctree` | `proctree` | Full `ps` process tree with user/CPU/mem, piped to `less` |
| `listeners` | `listeners` | `ss -tulnp` + raw `/proc/net/tcp` parsed to decimal ports |
| `readtcp` | `readtcp` | Parses `/proc/net/tcp` fully — IPs, ports, state — pure bash, no `ss`/`netstat` needed |
| `caps` | `caps` | Processes with non-zero effective capabilities (`CapEff`) — privesc surface |
| `suids` | `suids` | All SUID and SGID binaries across the filesystem |
| `worldwrite` | `worldwrite` | World-writable files outside `/proc`, `/sys`, `/tmp` |
| `croncheck` | `croncheck` | All cron jobs — `/etc/crontab`, `/etc/cron.d/`, every user's crontab |
| `timers` | `timers` | All systemd timers — the cron nobody audits |
| `envcheck` | `envcheck` | PATH entries, writable PATH dirs (privesc risk), sensitive env vars |
| `sudocheck` | `sudocheck` | Full sudoers dump + `sudo -l` |
| `rpmcheck` | `rpmcheck` | Files modified since RPM install — `rpm -Va` *(DEP: rpm, ships with RHEL)* |
| `etcdrift` | `etcdrift` | Modified `/etc` files vs RPM baseline — config drift detection |
| `sshaudit` | `sshaudit` | Active sshd_config lines, all authorized_keys, SSH agent sockets |
| `recent [mins]` | `recent 5` | Files modified in last N minutes (default 10), excludes `/proc`/`/sys`/`/run` |
| `pidinspect <pid>` | `pidinspect 1337` | Per-PID recon from `/proc` — cmdline, environ, open FDs, loaded libs. No `lsof` needed. |
| `histdump` | `histdump` | Bash history from all user home dirs + root |

### Network — /dev/tcp (No External Tools)

These use bash's built-in `/dev/tcp` — they work even when `nc`, `nmap`, `curl` are absent.

| Function | Usage | What it does |
|---|---|---|
| `portopen <host> <port>` | `portopen 10.0.0.1 22` | Check if port is open — prints `OPEN` or `CLOSED` |
| `tcpgrab <host> <port>` | `tcpgrab smtp.host.com 25` | Raw TCP connect + read — banner grabbing |
| `httpget <host> [/path]` | `httpget example.com /robots.txt` | Plain HTTP GET via `/dev/tcp`, port 80 — no curl needed |

### Transfer & Exfil Primitives

| Function | Usage | What it does |
|---|---|---|
| `tcpsend <file> <host> <port>` | `tcpsend dump.sql 10.0.0.2 9999` | Send a file over raw TCP via `/dev/tcp`. Receiver: `nc -l PORT > file` or `cat > file < /dev/tcp/0.0.0.0/PORT` |
| `b64out <file>` | `b64out /etc/passwd` | Base64 encode file to stdout — for copy-paste transfer |
| `b64in <outfile>` | `b64in decoded.bin` | Decode base64 from stdin to file |
| `serve [port]` | `serve 8080` | HTTP server in current dir via Python3/2. Falls back with `/dev/tcp` hint if Python absent. *(DEP: python3 or python2)* |

---

## MOTD

On every interactive login:

```
  hostname | kernel | AlmaLinux
  Uptime: up 3 days, 2 hours
  Load:   0.12 0.08 0.05
  Memory: 1823M used / 3840M total
  Disk:   4.2G used / 20G (22%)
  SELinux: Enforcing
  IPv4:   x.x.x.x

  "In SELinux we trust. The rest we audit."
```

Memory and load read directly from `/proc/meminfo` and `/proc/loadavg` — no `free` or `uptime` dependency.

---

## History

```bash
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
HISTTIMEFORMAT="%F %T  "   # timestamps on every entry
```

History is written, cleared, and re-read on every prompt (`PROMPT_COMMAND`) so that multiple terminal sessions don't clobber each other's history.

Up/down arrows do **history search** — type a partial command, then arrow up to cycle through only matching history entries.

---

## SSH Keepalive (Companion Config)

If you're on a flaky connection, add this to `~/.ssh/config` on your **client** machine:

```
Host *
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes
```

This tolerates up to 3 minutes of dead air before dropping the session. Pair with `tmux` on the server side for full session persistence across drops.

---

## Design Notes

**Why LotL?** On a fresh VPS, a jump box, or a client machine you don't own, you may not have install rights, internet access, or time. Everything here works on a base RHEL/AlmaLinux with zero additional packages. Functions that do require something beyond the base are explicitly marked `(DEP: pkg)`.

**Why two color variable sets?** Bash's `\[` and `\]` prompt escapes are only interpreted in the literal `PS1` string. If you call a function via `$()` inside `PS1` and that function returns `\e[32m` color codes, readline counts those bytes as visible characters, miscalculates line length, and your cursor position breaks. The fix is `\001`/`\002` (or `$'\001'`/`$'\002'`) inside functions — these are readline's actual non-printing character markers that survive subshell output. This file maintains `COLOR` vars for PS1 use and `_COLOR` vars for subshell use. Use the right one or you'll lose your cursor.

**`set -o noclobber`** — `>` will refuse to overwrite existing files. This is intentional. Use `>|` to explicitly force an overwrite.

---

## License

Do whatever you want with it.
