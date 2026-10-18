# CIS legacy AppArmor→SELinux migration — PILLAR-GATED, DEFAULT OFF. CIS DIL v2.0.0.
# Enable ONLY with overstate_cis:legacy_apparmor_migration: True on hosts provisioned
# pre-Feb-2025 (or Leap 15.x imports). Requires reboot + relabel. Never auto-reboots.
{% set migrate = salt['pillar.get']('overstate_cis:legacy_apparmor_migration', False) %}
{% if migrate %}

# CIS LEGACY-1 - Detect AppArmor LSM (informational, always reports)
legacy-1-detect-apparmor-lsm:
  cmd.run:
    - name: cat /sys/kernel/security/lsm 2>/dev/null || echo "lsm-unknown"; systemctl is-enabled apparmor 2>/dev/null || echo "apparmor-not-enabled"
    - stateful: False

# CIS LEGACY-2 - Disable and mask apparmor service (both LSMs simultaneously unsupported)
legacy-2-mask-apparmor-service:
  service.masked:
    - name: apparmor

# CIS LEGACY-3 - Strip AppArmor kernel params (delegates to bootloader logic, reinforced here)
legacy-3-strip-apparmor-grub:
  cmd.run:
    - name: sed -i 's/security=apparmor//g; s/apparmor=1//g; s/  */ /g' /etc/default/grub
    - onlyif: grep -Eq 'security=apparmor|apparmor=1' /etc/default/grub

# CIS LEGACY-4 - Trigger autorelabel on next boot (SELinux fresh-migration requirement)
legacy-4-trigger-autorelabel:
  cmd.run:
    - name: touch /.autorelabel && echo "AUTORELABEL ARMED — REBOOT REQUIRED"
    - creates: /.autorelabel

# CIS LEGACY-5 - Reboot required notification (never auto-reboot from Salt)
legacy-5-reboot-required-notice:
  test.show_notification:
    - text: "LEGACY MIGRATION: reboot required to complete SELinux relabel. Run `reboot` manually, expect long first boot."

{% else %}
# CIS LEGACY-SKIPPED - Migration disabled by default (informational)
legacy-skipped-migration-disabled:
  test.show_notification:
    - text: "legacy_apparmor_migration=False — skipping AppArmor→SELinux migration (default, safe)."
{% endif %}
