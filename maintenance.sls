# CIS 6.1.x system maintenance — perms, world-writable, unowned, SUID. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import controls with context %}

# CIS 6.1.1 - passwd/group/shadow permissions (idempotent, replace False keeps content)
{% if controls.get('passwd_perms', True) %}
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
{% endif %}

# CIS 6.1.x - world-writable files / unowned files / SUID review are REPORT-ONLY here.
# Enforcement (chmod/chown/remove) is intentionally NOT automated — see audit.sls reporters.
# Rationale: auto-fixing breaks Docker overlays, k8s volumes, GUI caches. Operator reviews audit output.

# CIS 6.1.x L2 - USB storage blacklist (WARNING: breaks installers, backup drives, VMs).
# Triple-gated: level 2 AND usb_disable: True AND controls.usb_storage. file.managed with inline contents.
{% if salt['pillar.get']('overstate_cis:level', 1) >= 2 and controls.get('usb_storage', True) %}
6.1.x-L2-usb-storage-blacklist:
  file.managed:
    - name: /etc/modprobe.d/cis-usb-storage.conf
    - contents: |
        install usb-storage /bin/true
    - mode: '0644'
    - onlyif: test "{{ salt['pillar.get']('overstate_cis:usb_disable', False) }}" = "True"
    # CIS 6.1.x L2 - Disable USB storage (WARNING: breaks installers, backup drives, VMs)
{% endif %}
