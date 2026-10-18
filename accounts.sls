# CIS 5.3-5.4 / 6.2 accounts & password policy. CIS DIL v2.0.0.
{% set level = salt['pillar.get']('overstate_cis:level', 1) %}

# CIS 5.4.x - login.defs PASS_MAX_DAYS / MIN_DAYS / WARN_AGE
5.4.x-login-defs-max-days:
  file.replace:
    - name: /etc/login.defs
    - pattern: '^PASS_MAX_DAYS.*'
    - repl: 'PASS_MAX_DAYS   {{ salt['pillar.get']('overstate_cis:pass_max_days', 365) }}'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f /etc/login.defs
    # CIS 5.4.1 - Ensure password expiration is 365 days or less

5.4.x-login-defs-min-days:
  file.replace:
    - name: /etc/login.defs
    - pattern: '^PASS_MIN_DAYS.*'
    - repl: 'PASS_MIN_DAYS   {{ salt['pillar.get']('overstate_cis:pass_min_days', 1) }}'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f /etc/login.defs
    # CIS 5.4.1 - Ensure minimum password age is configured

5.4.x-login-defs-warn-age:
  file.replace:
    - name: /etc/login.defs
    - pattern: '^PASS_WARN_AGE.*'
    - repl: 'PASS_WARN_AGE   {{ salt['pillar.get']('overstate_cis:pass_warn_age', 7) }}'
    - append_if_not_found: True
    - backup: minion
    - onlyif: test -f /etc/login.defs
    # CIS 5.4.1 - Ensure password warning age is configured

# CIS 5.3.x - faillock lockout policy (common-auth)
5.3.x-faillock-conf:
  file.managed:
    - name: /etc/security/faillock.conf
    - source: salt://overstate_cis/templates/faillock.conf.j2
    - template: jinja
    - backup: minion
    # CIS 5.3.x - Ensure account lockout (deny=5, unlock_time=900, even_deny_root)

# CIS 5.4.x - TMOUT session timeout (WARNING: breaks long GUI/SSH sessions, L2-gated example)
{% if level >= 2 %}
5.4.x-L2-tmout-600:
  file.managed:
    - name: /etc/profile.d/cis-tmout.sh
    - contents: |
        TMOUT={{ salt['pillar.get']('overstate_cis:tmout', 600) }}
        readonly TMOUT
        export TMOUT
    - mode: '0644'
    - onlyif: test "{{ salt['pillar.get']('overstate_cis:tmout_enable', False) }}" = "True"
    # CIS 5.4.x L2 - Session timeout TMOUT (WARNING: kills idle shells, explicit opt-in)
{% endif %}

# CIS 5.4.x - root login restrictions (securetty + nologin shell check documented in audit)
5.4.x-root-securetty:
  file.managed:
    - name: /etc/securetty
    - mode: '0600'
    - replace: False
    # CIS 5.4.x - Ensure root login is restricted to system console

# WARNING L2: disable Ctrl-Alt-Del (mask) — commented by default, breaks physical consoles if unexpected
# 5.4.x-L2-mask-ctrlaltdel:
#   service.masked:
#     - name: ctrl-alt-del.target
#     # CIS L2 - Disable Ctrl-Alt-Del reboot (WARNING: changes console behavior)
