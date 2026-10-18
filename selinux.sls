# CIS 1.6.x SELinux — native enforcing/targeted on Fedora + openSUSE. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import overstate_cis with context %}
{% set booleans = salt['pillar.get']('overstate_cis:selinux_booleans', {}) %}

# CIS 1.6.1 - Ensure SELinux is installed
1.6.1-selinux-policy-installed:
  pkg.installed:
    - name: {{ overstate_cis.selinux_policy_pkg }}

# CIS 1.6.2 - Ensure SELinux is in enforcing mode (/etc/selinux/config)
1.6.2-selinux-config-enforcing:
  file.replace:
    - name: /etc/selinux/config
    - pattern: '^SELINUX=.*'
    - repl: 'SELINUX=enforcing'
    - append_if_not_found: True
    - backup: minion

# CIS 1.6.2 - Ensure SELINUXTYPE=targeted
1.6.2-selinux-config-targeted:
  file.replace:
    - name: /etc/selinux/config
    - pattern: '^SELINUXTYPE=.*'
    - repl: 'SELINUXTYPE=targeted'
    - append_if_not_found: True
    - backup: minion

# CIS 1.6.3 - Ensure SELinux enforcing via state module (requires reboot if changing)
1.6.3-selinux-mode-enforcing:
  selinux.mode:
    - name: enforcing

# CIS 1.6.x - Manage booleans via pillar (loop, idempotent, persist)
{% for bname, bval in booleans.items() %}
{{ '1.6.x-selinux-boolean-' ~ bname }}:
  selinux.boolean:
    - name: {{ bname }}
    - value: {{ bval }}
    - persist: True
    # CIS 1.6.x - Ensure SELinux boolean {{ bname }} is {{ bval }}
{% endfor %}
