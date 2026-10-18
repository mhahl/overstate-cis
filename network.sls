# CIS 3.x network — firewalld + sysctl + wireless. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import overstate_cis with context %}
{% set level = salt['pillar.get']('overstate_cis:level', 1) %}
{% set disable_ipv6 = salt['pillar.get']('overstate_cis:disable_ipv6', False) %}
{% set sysctl_extra = salt['pillar.get']('overstate_cis:sysctl', {}) %}
{% set sysctl_base = {
  'net.ipv4.ip_forward': 0,
  'net.ipv4.conf.all.send_redirects': 0,
  'net.ipv4.conf.default.send_redirects': 0,
  'net.ipv4.conf.all.accept_source_route': 0,
  'net.ipv4.conf.default.accept_source_route': 0,
  'net.ipv4.conf.all.accept_redirects': 0,
  'net.ipv4.conf.default.accept_redirects': 0,
  'net.ipv4.conf.all.secure_redirects': 0,
  'net.ipv4.conf.default.secure_redirects': 0,
  'net.ipv4.conf.all.log_martians': 1,
  'net.ipv4.conf.default.log_martians': 1,
  'net.ipv4.icmp_echo_ignore_broadcasts': 1,
  'net.ipv4.icmp_ignore_bogus_error_responses': 1,
  'net.ipv4.conf.all.rp_filter': 1,
  'net.ipv4.conf.default.rp_filter': 1,
  'net.ipv4.tcp_syncookies': 1,
  'net.ipv6.conf.all.accept_ra': 0,
  'net.ipv6.conf.default.accept_ra': 0,
} %}
{% set sysctl_all = dict(sysctl_base, **sysctl_extra) %}

# CIS 3.1.x - Ensure firewalld installed + enabled (nftables backend)
3.1.x-firewalld-installed:
  pkg.installed:
    - name: {{ overstate_cis.firewalld_pkg }}

3.1.x-firewalld-enabled:
  service.running:
    - name: {{ overstate_cis.firewalld_svc }}
    - enable: True
    - require:
      - pkg: 3.1.x-firewalld-installed
    # CIS 3.1.x - Ensure firewalld is running with nftables backend

3.1.x-firewalld-backend-nftables:
  file.replace:
    - name: /etc/firewalld/firewalld.conf
    - pattern: '^FirewallBackend=.*'
    - repl: 'FirewallBackend=nftables'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f /etc/firewalld/firewalld.conf
    # CIS 3.1.x - Ensure firewalld uses nftables backend

{% set strict_drop = level >= 2 and salt['pillar.get']('overstate_cis:firewalld_strict_drop', False) %}
{% set zone = 'drop' if strict_drop else salt['pillar.get']('overstate_cis:firewalld_default_zone', 'public') %}
# CIS 3.1.x - Default zone (pillar-tunable; L2 + firewalld_strict_drop tightens to drop)
3.1.x-firewalld-default-zone:
  cmd.run:
    - name: firewall-cmd --set-default-zone={{ zone }}
    - unless: firewall-cmd --get-default-zone | grep -q {{ zone }}
    - onlyif: systemctl is-active firewalld
    # CIS 3.1.x - Ensure firewalld default zone (WARNING: drop breaks Docker/k8s, explicit opt-in)

# CIS 3.2.x - Kernel network params via sysctl template (checksum-backed)
3.2.x-sysctl-cis-params:
  file.managed:
    - name: /etc/sysctl.d/99-cis.conf
    - source: salt://overstate_cis/templates/sysctl-cis.conf.j2
    - template: jinja
    - backup: minion
    - context:
        params: {{ sysctl_all }}
    # CIS 3.2.x - Ensure kernel network parameters are hardened

3.2.x-sysctl-apply:
  cmd.run:
    - name: sysctl --system
    - onchanges:
      - file: 3.2.x-sysctl-cis-params

# CIS 3.3.x - Wireless: mask wpa_supplicant (laptops break if WiFi needed — pillar opt-out)
3.3.x-wireless-masked:
  service.masked:
    - name: wpa_supplicant
    - onlyif: test "{{ salt['pillar.get']('overstate_cis:disable_wireless', True) }}" = "True"
    # CIS 3.3.x - Ensure wireless interfaces are disabled (WARNING: breaks WiFi laptops)

# CIS 3.x - IPv6: harden by default, disable only if explicitly requested (WARNING: breaks workloads)
3.x-ipv6-disable-optin:
  sysctl.present:
    - name: net.ipv6.conf.all.disable_ipv6
    - value: 1
    - onlyif: test "{{ disable_ipv6 }}" = "True"
    # CIS 3.x - Disable IPv6 (OPT-IN, WARNING: breaks Docker/k8s, commented logic gated)
