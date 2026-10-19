# CIS 1.6.x SELinux — native enforcing/targeted on Fedora + openSUSE. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import overstate_cis, controls with context %}
{% set booleans = salt['pillar.get']('overstate_cis:selinux_booleans', {}) %}

# The `selinux` control switches the WHOLE SELinux section (policy install,
# /etc/selinux/config, runtime mode, booleans). Set controls.selinux: False to
# leave SELinux untouched (e.g. hosts that intentionally keep AppArmor/permissive).
{% if controls.get('selinux', True) %}
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

# CIS 1.6.3 - Runtime SELinux management (state module). Gated by
# selinux_runtime_managed in map.jinja: onlyif/unless cannot help here because
# Salt fails state resolution ("was not found... __virtual__ returned False") at
# compile time when python bindings are absent, before requisites are evaluated.
# SUSE therefore enforces via /etc/selinux/config (effective at boot); set
# overstate_cis:lookup: {selinux_runtime_managed: True} once bindings exist.
{% if overstate_cis.selinux_runtime_managed %}
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
{% endif %}
{% endif %}
