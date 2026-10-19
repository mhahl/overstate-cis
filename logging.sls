# CIS 4.x logging & auditing. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import overstate_cis, controls with context %}
{% set level = salt['pillar.get']('overstate_cis:level', 1) %}
# Single render-time gate for the immutable-audit L2 block so both the state
# and the audit-reload onchanges reference it consistently. The audit_immutable
# pillar flag remains a runtime onlyif on the state itself.
{% set immutable_rendered = level >= 2 and controls.get('audit_immutable', True) %}

# CIS 4.1.x - rsyslog installed + enabled
{% if controls.get('rsyslog', True) %}
4.1.x-rsyslog-installed:
  pkg.installed:
    - name: {{ overstate_cis.rsyslog_pkg }}
    # CIS 4.1.1 - Ensure rsyslog is installed

4.1.x-rsyslog-enabled:
  service.running:
    - name: {{ overstate_cis.rsyslog_svc }}
    - enable: True
    # CIS 4.1.2 - Ensure rsyslog service is enabled

4.1.x-rsyslog-cis-conf:
  file.managed:
    - name: /etc/rsyslog.d/99-cis.conf
    - source: salt://overstate_cis/templates/rsyslog-cis.conf.j2
    - template: jinja
    - backup: minion
    # CIS 4.1.x - Ensure rsyslog default file permissions and forwarding are configured
{% endif %}

# CIS 4.2.x - logrotate present (config left stock, permissions checked in audit)
{% if controls.get('logrotate', True) %}
4.2.x-logrotate-installed:
  pkg.installed:
    - name: logrotate
    # CIS 4.2.1 - Ensure logrotate is installed
{% endif %}

# CIS 4.2.x - journald persistent storage (skipped where journald is not installed)
{% if controls.get('journald_persistent', True) %}
4.2.x-journald-persistent:
  file.replace:
    - name: /etc/systemd/journald.conf
    - pattern: '^#?Storage=.*'
    - repl: 'Storage=persistent'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f /etc/systemd/journald.conf
    # CIS 4.2.2 - Ensure journald persistent logging is enabled
{% endif %}

# CIS 4.3.x - auditd installed + enabled, ruleset in /etc/audit/rules.d/
{% if controls.get('auditd', True) %}
4.3.x-auditd-installed:
  pkg.installed:
    - name: {{ overstate_cis.audit_pkg }}
    # CIS 4.3.1 - Ensure auditd is installed

4.3.x-auditd-enabled:
  service.running:
    - name: {{ overstate_cis.auditd_svc }}
    - enable: True
    # CIS 4.3.2 - Ensure auditd service is enabled
{% endif %}

{% if controls.get('audit_rules', True) %}
4.3.x-audit-rules-cis:
  file.managed:
    - name: /etc/audit/rules.d/cis.rules
    - source: salt://overstate_cis/templates/audit-cis.rules.j2
    - template: jinja
    - backup: minion
    # CIS 4.3.x - Ensure full audit ruleset (time, identity, DAC, mounts, modules, immutable opt-in)

4.3.x-audit-max-log-file:
  file.replace:
    - name: /etc/audit/auditd.conf
    - pattern: '^max_log_file\s*=.*'
    - repl: 'max_log_file = {{ salt['pillar.get']('overstate_cis:audit_max_log_file_mb', 50) }}'
    - append_if_not_found: True
    - backup: minion
    # CIS 4.3.x - Ensure audit log size is configured

4.3.x-audit-reload:
  cmd.run:
    - name: augenrules --load
    - onchanges:
      - file: 4.3.x-audit-rules-cis
{% if immutable_rendered %}
      - file: 4.3.x-L2-audit-immutable
{% endif %}
    - onlyif: test -x /sbin/augenrules
{% endif %}

# CIS 4.3.x L2 - Immutable audit rules (WARNING: needs reboot to modify).
# Triple-gated: level 2 AND audit_immutable: True AND controls.audit_immutable.
# file.append is idempotent.
{% if immutable_rendered %}
4.3.x-L2-audit-immutable:
  file.append:
    - name: /etc/audit/rules.d/cis.rules
    - text: '-e 2'
    - onlyif: test "{{ salt['pillar.get']('overstate_cis:audit_immutable', False) }}" = "True"
    - require:
      - file: 4.3.x-audit-rules-cis
    # CIS 4.3.x L2 - Immutable audit rules (WARNING: needs reboot to modify, enable explicitly)
{% endif %}
