#!/usr/bin/env bash
# Verify Linux hardening applied by Ansible (roles/common). Exit 1 if any check fails.
# Run on the server:  sudo ./security/audit-host.sh
set -uo pipefail
FAILS=0
check() { # check "description" command...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then printf 'PASS  %s\n' "$d"; else printf 'FAIL  %s\n' "$d"; FAILS=$((FAILS+1)); fi
}
sshd_val() { sshd -T 2>/dev/null | grep -i "^$1 " | awk '{print tolower($2)}'; }

check "SSH root login disabled"        test "$(sshd_val permitrootlogin)" = "no"
check "SSH password auth disabled"     test "$(sshd_val passwordauthentication)" = "no"
check "UFW firewall active"            sh -c 'ufw status | grep -q "Status: active"'
check "fail2ban running"               systemctl is-active --quiet fail2ban
check "unattended-upgrades enabled"    systemctl is-enabled --quiet unattended-upgrades
check "SYN cookies enabled"            test "$(sysctl -n net.ipv4.tcp_syncookies)" = "1"
check "ICMP redirects ignored"         test "$(sysctl -n net.ipv4.conf.all.accept_redirects)" = "0"
check "No world-writable files in /opt/ecommerce" sh -c '[ -z "$(find /opt/ecommerce -xdev -type f -perm -0002 2>/dev/null)" ]'
check "Docker daemon has no-new-privileges" sh -c 'grep -q "no-new-privileges" /etc/docker/daemon.json'

echo
if [[ $FAILS -eq 0 ]]; then echo "All hardening checks passed"; else echo "$FAILS check(s) failed"; exit 1; fi
