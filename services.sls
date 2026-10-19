# CIS 2.x services — disable insecure/obsolete, MTA local-only. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import controls with context %}
{% set mask_list = salt['pillar.get']('overstate_cis:mask_services', ['xinetd', 'avahi-daemon', 'cups', 'dhcpd', 'slpd']) %}

# CIS 2.1.x - Ensure xinetd and insecure services are masked
{% if controls.get('mask_services', True) %}
{% for svc in mask_list %}
{{ '2.1.x-service-masked-' ~ svc }}:
  service.masked:
    - name: {{ svc }}
    # CIS 2.1.x - Ensure {{ svc }} is masked (obsolete/insecure)
{% endfor %}
{% endif %}

# CIS 2.2.x - Ensure Avahi / print servers disabled (covered above + explicit cups socket)
{% if controls.get('cups_socket', True) %}
2.2.x-cups-socket-masked:
  service.masked:
    - name: cups.socket
    # CIS 2.2.x - Ensure print server socket is masked
{% endif %}

# CIS 2.3.x - Ensure MTA is local-only (postfix inet_interfaces=localhost)
{% if controls.get('postfix_local_only', True) %}
2.3.x-postfix-local-only:
  file.replace:
    - name: /etc/postfix/main.cf
    - pattern: '^inet_interfaces\s*=.*'
    - repl: 'inet_interfaces = localhost'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f /etc/postfix/main.cf
    # CIS 2.3.x - Ensure MTA is configured for local-only mode
{% endif %}
