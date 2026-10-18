# CIS 0 — Entrypoint / orchestrator. CIS DIL v2.0.0.
# Single entrypoint to avoid orphan states. Top file should only include overstate_cis.
{% set level = salt['pillar.get']('overstate_cis:level', 1) %}
{% set enforce = salt['pillar.get']('overstate_cis:enforce', False) %}

include:
  - overstate_cis.audit
{% if enforce %}
  - overstate_cis.packages
  - overstate_cis.config
  - overstate_cis.services
{% endif %}
# NOTE: when enforce=False (default, audit-only), only audit.sls runs.
# Set overstate_cis:enforce: True to mutate. Level: {{ level }}.
