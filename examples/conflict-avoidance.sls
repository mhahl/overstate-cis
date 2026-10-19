# examples/conflict-avoidance.sls — ready-to-copy pillar: every control
# with its enabled/disabled toggle (conflict avoidance).
#
# This is NOT part of the applied formula (no top file targets it). It is
# reference material: copy the block you need into your real pillar.
#
# Rules of thumb:
#   - Every control defaults to True (enabled). You only need to write the
#     keys you want to turn OFF.
#   - Toggles layer ON TOP of the existing gates: e.g. `tmout: True` still
#     requires `level: 2` AND `tmout_enable: True`; `wireless: True` still
#     requires `disable_wireless: True`; `usb_storage: True` still requires
#     `level: 2` AND `usb_disable: True`.
#   - The only state never toggled is the safety guard
#     0-guard-supported-os-family (fails closed on unsupported OSes).

# ── Option A: everything enabled (equivalent to omitting `controls` entirely) ──
overstate_cis:
  enforce: False          # False = audit-only; True = enforce
  level: 1                # 1 = L1 controls; 2 = + L2 controls (still flag-gated)

  controls:
    # Packages & GPG (packages.sls)
    packages_required: True      # install all required hardening packages
    gpg_enforce: True            # dnf/zypp gpgcheck=1

    # Network (network.sls)
    firewalld: True              # install + enable firewalld, nftables backend
    firewalld_default_zone: True # firewall-cmd --set-default-zone
    firewall_strict_drop: True   # L2 default-zone drop tightening (needs L2 + flag)
    sysctl_kernel: True          # /etc/sysctl.d/99-cis.conf + apply
    wireless: True               # mask wpa_supplicant (needs disable_wireless)
    ipv6: True                   # IPv6 disable opt-in (needs disable_ipv6)

    # Services (services.sls)
    mask_services: True          # mask xinetd/avahi/cups/dhcpd/slpd
    cups_socket: True            # mask cups.socket
    postfix_local_only: True     # postfix inet_interfaces=localhost

    # Accounts & passwords (accounts.sls)
    password_aging: True         # login.defs PASS_MAX/MIN/WARN days
    faillock: True               # /etc/security/faillock.conf lockout
    tmout: True                  # TMOUT profile (needs L2 + tmout_enable)
    securetty: True              # /etc/securetty 0600
    ctrlaltdel: True             # mask ctrl-alt-del.target (needs L2 + flag)

    # Access (access.sls)
    sudo: True                   # sudo pkg + sudoers 0440
    cron_perms: True             # cron.allow/crontab 0600
    sshd: True                   # host keys + sshd_config + sshd service
    pwquality: True              # /etc/security/pwquality.conf
    umask: True                  # umask 027 (needs L2 + umask_restrictive)

    # Logging & auditing (logging.sls)
    rsyslog: True                # rsyslog pkg + service + 99-cis.conf
    logrotate: True              # logrotate pkg
    journald_persistent: True    # journald Storage=persistent
    auditd: True                 # audit pkg + service
    audit_rules: True            # cis.rules + auditd.conf size + augenrules load
    audit_immutable: True        # -e 2 immutable rules (needs L2 + audit_immutable)

    # Maintenance & SELinux (maintenance.sls, selinux.sls)
    passwd_perms: True           # /etc/passwd|group|shadow|gshadow modes
    usb_storage: True            # usb-storage blacklist (needs L2 + usb_disable)
    selinux: True                # SELinux policy + enforcing/targeted + booleans

    # Bootloader & migration (bootloader.sls, legacy_migration.sls)
    grub: True                   # grub cmdline + AppArmor strip + grub.cfg regen
    legacy_migration: True       # AppArmor→SELinux migration (needs the flag below)

    # Audit reports (audit.sls)
    audit_reports: True          # all read-only audit reporters

# ── Option B: conflict-avoidance, minimal form ────────────────────────────────
# Keep everything on; list only what you want OFF. Example: Docker/VM host
# at Level 2 (fail-safe because Option A above and this block are mutually
# exclusive — use ONE of them in a real pillar):
#
# overstate_cis:
#   enforce: True
#   level: 2
#   controls:
#     firewalld_default_zone: False   # keep Docker's own zone handling
#     firewall_strict_drop: False     # never flip default zone to drop
#     usb_storage: False              # VMs need USB passthrough
#     wireless: False                 # if it's a laptop / needs WiFi
#     grub: False                     # containers / transactional hosts w/o grub
#     audit_reports: False            # skip the read-only scanners