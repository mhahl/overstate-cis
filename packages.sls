# CIS 1.x/2.x/4.x packages. CIS DIL v2.0.0. Salt 3008.
{% from "overstate_cis/map.jinja" import overstate_cis with context %}
{% set pkgs = [
  overstate_cis.audit_pkg,
  overstate_cis.ssh_server_pkg,
  overstate_cis.pwquality_pkg,
  overstate_cis.selinux_core_pkg,
  overstate_cis.selinux_policy_pkg,
  overstate_cis.rsyslog_pkg,
  overstate_cis.chrony_pkg,
  overstate_cis.firewalld_pkg,
  overstate_cis.sudo_pkg
] + ([overstate_cis.selinux_python_pkg] if overstate_cis.selinux_python_pkg else []) %}
{% set gpg_enforce = salt['pillar.get']('overstate_cis:pkg_gpg_enforce', True) %}

# CIS 1.2.x — package manager GPG enforcement (RedHat dnf.conf)
{% if grains['os_family'] == 'RedHat' %}
1.2.1-dnf-gpgcheck-enforced:
  file.replace:
    - name: {{ overstate_cis.dnf_conf }}
    - pattern: '^gpgcheck\s*=.*'
    - repl: 'gpgcheck=1'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f {{ overstate_cis.dnf_conf }}
    # CIS 1.2.1 - Ensure gpgcheck is globally activated
{% endif %}

# CIS 1.2.x — zypper GPG enforcement (Suse zypp.conf + repo gpgcheck)
{% if grains['os_family'] == 'Suse' %}
1.2.1-zypp-gpgcheck-enforced:
  file.replace:
    - name: {{ overstate_cis.zypp_conf }}
    - pattern: '^gpgcheck\s*=.*'
    - repl: 'gpgcheck = 1'
    - append_if_not_found: True
    - backup: minion
    # CIS 1.2.1 - Ensure gpgcheck is globally activated (zypper)
{% endif %}

# CIS 1.6.x / 2.x / 4.x — required packages present
{% for pkg in pkgs %}
{{ 'pkg-' ~ pkg ~ '-installed' }}:
  pkg.installed:
    - name: {{ pkg }}
    # CIS 1.6/2.2/4.1 — Ensure required hardening packages are installed
{% endfor %}
