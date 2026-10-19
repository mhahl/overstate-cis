# CIS 1.4.x bootloader — SELinux cmdline, strip AppArmor. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import overstate_cis, controls with context %}
{% set grub_file = overstate_cis.grub_default_file %}
{% set is_transactional = salt['cmd.run']('test -x /usr/sbin/transactional-update && echo yes || echo no', python_shell=True).strip() == 'yes' %}

# The `grub` control switches the whole bootloader section (cmdline edit, AppArmor
# strip, grub.cfg regen). Set controls.grub: False on systems without grub tooling
# (containers, transactional hosts that regenerate elsewhere, etc.).
{% if controls.get('grub', True) %}
# CIS 1.4.1 - Ensure bootloader cmdline includes security=selinux selinux=1 enforcing=1
1.4.1-grub-selinux-cmdline:
  file.replace:
    - name: {{ grub_file }}
    - pattern: '^GRUB_CMDLINE_LINUX="[^"]*"'
    - repl: 'GRUB_CMDLINE_LINUX="security=selinux selinux=1 enforcing=1"'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f {{ grub_file }}

# CIS 1.4.1 - Remove residual security=apparmor (legacy installs carry it; both LSMs unsupported together)
1.4.1-grub-strip-apparmor-param:
  cmd.run:
    - name: sed -i 's/security=apparmor//g; s/  */ /g' {{ grub_file }}
    - onlyif: grep -q 'security=apparmor' {{ grub_file }}

{% if not is_transactional %}
# CIS 1.4.2 - Regenerate grub.cfg (non-transactional path)
1.4.2-grub-mkconfig-bios:
  cmd.run:
    - name: {{ overstate_cis.grub_mkconfig_bios }}
    - onchanges:
      - file: 1.4.1-grub-selinux-cmdline
      - cmd: 1.4.1-grub-strip-apparmor-param
{% else %}
# CIS 1.4.2 - Transactional openSUSE path (Tumbleweed/Leap transactional)
1.4.2-grub-transactional-update:
  cmd.run:
    - name: transactional-update run {{ overstate_cis.grub_mkconfig_bios }}
    - onchanges:
      - file: 1.4.1-grub-selinux-cmdline
      - cmd: 1.4.1-grub-strip-apparmor-param
{% endif %}
{% endif %}
