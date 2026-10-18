# CIS 5.x access control — sudo, cron, sshd, PAM, umask. CIS DIL v2.0.0.
{% from "overstate_cis/map.jinja" import overstate_cis with context %}
{% set level = salt['pillar.get']('overstate_cis:level', 1) %}
{% set sshd_overrides = salt['pillar.get']('overstate_cis:sshd_options', {}) %}

# CIS 5.1.x - sudo package + sudoers perms
5.1.x-sudo-installed:
  pkg.installed:
    - name: {{ overstate_cis.sudo_pkg }}
    # CIS 5.1.1 - Ensure sudo is installed

5.1.x-sudoers-perms:
  file.managed:
    - name: /etc/sudoers
    - mode: '0440'
    - replace: False
    # CIS 5.1.2 - Ensure sudoers permissions are 0440

# CIS 5.1.x - cron perms
5.1.x-cron-allow-perms:
  file.managed:
    - name: /etc/cron.allow
    - mode: '0600'
    - replace: False
    # CIS 5.1.x - Ensure cron permissions are restricted

5.1.x-crontab-perms:
  file.managed:
    - name: /etc/crontab
    - mode: '0600'
    - replace: False
    # CIS 5.1.x - Ensure crontab permissions are 0600

# CIS 5.2.x - sshd_config full-file template (all CIS options as managed k/v, pillar-overridable)
5.2.x-sshd-config-managed:
  file.managed:
    - name: /etc/ssh/sshd_config
    - source: salt://overstate_cis/templates/sshd_config.j2
    - template: jinja
    - backup: minion
    - context:
        overrides: {{ sshd_overrides }}
    - check_cmd: /usr/sbin/sshd -t -f
    # CIS 5.2.x - Ensure sshd_config contains full CIS option list (PermitRootLogin no, PasswordAuthentication, X11Forwarding no, etc.)

5.2.x-sshd-service:
  service.running:
    - name: {{ overstate_cis.ssh_svc }}
    - enable: True
    - watch:
      - file: 5.2.x-sshd-config-managed

# CIS 5.3.x - PAM pwquality (uses libpwquality on both, see map.jinja)
5.3.x-pwquality-conf:
  file.managed:
    - name: /etc/security/pwquality.conf
    - source: salt://overstate_cis/templates/pwquality.conf.j2
    - template: jinja
    - backup: minion
    # CIS 5.3.x - Ensure password quality policy (minlen 14, dcredit/ucredit/ocredit/lcredit)

# CIS 5.x L2 - restrictive umask 027 (WARNING: breaks GUI/desktop apps, Docker builds)
{% if level >= 2 %}
5.x-L2-umask-027-profile:
  file.append:
    - name: /etc/profile
    - text: 'umask 027'
    - onlyif: test "{{ salt['pillar.get']('overstate_cis:umask_restrictive', False) }}" = "True"
    # CIS 5.x L2 - Restrictive umask (WARNING: breaks workloads, explicit opt-in required)
{% endif %}
