# CIS audit.sls — READ-ONLY reporting, test=True safe. CIS DIL v2.0.0.
# No file.managed/pkg/service changes here. Only cmd.run + test.show_notification.
# Safe to run with `salt-call --local state.apply overstate_cis.audit test=True`.

# CIS 1.x - partition scheme / mount checks (report-only, never partitions)
1.x-audit-mount-report:
  cmd.run:
    - name: >-
        mount | grep -E ' / | /var| /tmp| /home' || echo "AUDIT: no separate partitions detected (review manually)"
    - stateful: False
    # CIS 1.x - Report filesystem partition scheme

# CIS 1.6.x - SELinux status report
1.6.x-audit-selinux-status:
  cmd.run:
    - name: >-
        sestatus 2>/dev/null || getenforce 2>/dev/null || echo "AUDIT FAIL: SELinux tooling missing"
    - stateful: False
    # CIS 1.6.x - Report SELinux enforcing/targeted (warns if no policy loaded on Leap)

# CIS 2.x - insecure services report
2.x-audit-insecure-services:
  cmd.run:
    - name: >-
        systemctl is-enabled xinetd avahi-daemon cups dhcpd 2>&1 || echo "AUDIT: services not enabled (pass)"
    - stateful: False
    # CIS 2.x - Report obsolete/insecure services

# CIS 3.x - sysctl + firewalld report
3.x-audit-sysctl-report:
  cmd.run:
    - name: >-
        sysctl net.ipv4.tcp_syncookies net.ipv4.conf.all.log_martians net.ipv4.conf.all.rp_filter 2>/dev/null || echo "AUDIT: sysctl keys missing"
    - stateful: False
    # CIS 3.x - Report SYN cookies, martians, rp_filter

3.x-audit-firewalld-report:
  cmd.run:
    - name: >-
        firewall-cmd --get-default-zone 2>/dev/null; firewall-cmd --list-all 2>/dev/null || echo "AUDIT: firewalld not running"
    - stateful: False
    # CIS 3.x - Report firewalld default zone and rules

# CIS 4.x - logging report
4.x-audit-logging-report:
  cmd.run:
    - name: >-
        systemctl is-enabled rsyslog auditd 2>&1; test -f /etc/audit/rules.d/cis.rules && echo "cis.rules present" || echo "AUDIT FAIL: cis.rules missing"
    - stateful: False
    # CIS 4.x - Report rsyslog/auditd/cis.rules presence

# CIS 5.x - sshd + sudo + cron report
5.x-audit-sshd-report:
  cmd.run:
    - name: >-
        /usr/sbin/sshd -T 2>/dev/null | grep -Ei 'permitrootlogin|passwordauthentication|x11forwarding|maxauthtries' || echo "AUDIT: sshd -T unavailable"
    - stateful: False
    # CIS 5.2.x - Report effective sshd options

5.x-audit-sudo-cron-report:
  cmd.run:
    - name: >-
        stat -c '%a %n' /etc/sudoers /etc/crontab 2>/dev/null || echo "AUDIT: sudo/cron perms check failed"
    - stateful: False
    # CIS 5.1.x - Report sudo/cron permissions

# CIS 6.x - world-writable / unowned / SUID report (never auto-fix)
6.x-audit-world-writable-report:
  cmd.run:
    - name: >-
        df --local -P | awk 'NR>1{print $6}' | xargs -I{} find {} -xdev -type f -perm -0002 -print 2>/dev/null | head -20; echo "AUDIT: world-writable scan complete (review output, no changes made)"
    - stateful: False
    - onlyif: test "{{ salt['pillar.get']('overstate_cis:audit_ww_files', True) }}" = "True"
    # CIS 6.1.x - Report world-writable files (WARNING: do not auto-chmod Docker/k8s volumes)

6.x-audit-unowned-report:
  cmd.run:
    - name: >-
        df --local -P | awk 'NR>1{print $6}' | xargs -I{} find {} -xdev -nouser -o -nogroup 2>/dev/null | head -20; echo "AUDIT: unowned scan complete"
    - stateful: False
    # CIS 6.1.x - Report unowned files

6.x-audit-suid-report:
  cmd.run:
    - name: >-
        find / -xdev -type f -perm -4000 -print 2>/dev/null | head -30; echo "AUDIT: SUID review complete (manual review required)"
    - stateful: False
    # CIS 6.1.x - Report SUID binaries for manual review
