# CIS 6.1.x system maintenance — perms, world-writable, unowned, SUID. CIS DIL v2.0.0.

# CIS 6.1.1 - passwd/group/shadow permissions (idempotent, replace False keeps content)
6.1.1-passwd-perms:
  file.managed:
    - name: /etc/passwd
    - mode: '0644'
    - replace: False
    # CIS 6.1.1 - Ensure /etc/passwd permissions are 0644

6.1.1-group-perms:
  file.managed:
    - name: /etc/group
    - mode: '0644'
    - replace: False
    # CIS 6.1.1 - Ensure /etc/group permissions are 0644

6.1.1-shadow-perms:
  file.managed:
    - name: /etc/shadow
    - mode: '0000'
    - replace: False
    # CIS 6.1.1 - Ensure /etc/shadow permissions are 0000

6.1.1-gshadow-perms:
  file.managed:
    - name: /etc/gshadow
    - mode: '0000'
    - replace: False
    # CIS 6.1.1 - Ensure /etc/gshadow permissions are 0000

# CIS 6.1.x - world-writable files / unowned files / SUID review are REPORT-ONLY here.
# Enforcement (chmod/chown/remove) is intentionally NOT automated — see audit.sls reporters.
# Rationale: auto-fixing breaks Docker overlays, k8s volumes, GUI caches. Operator reviews audit output.

# WARNING: USB storage blocking (L2, breaks installers/VMs) — commented by default
# 6.1.x-L2-usb-storage-blacklist:
#   file.managed:
#     - name: /etc/modprobe.d/cis-usb-storage.conf
#     - contents: |
#         install usb-storage /bin/true
#     - onlyif: test "{{ salt['pillar.get']('overstate_cis:usb_disable', False) }}" = "True"
#     # CIS 6.1.x L2 - Disable USB storage (WARNING: breaks installers, backup drives, VMs)
