# CIS config aggregator — included from init.sls only. Do not apply standalone.
include:
  - overstate_cis.selinux
  - overstate_cis.bootloader
  - overstate_cis.network
  - overstate_cis.logging
  - overstate_cis.access
  - overstate_cis.accounts
  - overstate_cis.maintenance
# legacy_migration.sls is NOT included here on purpose:
# apply manually with pillar overstate_cis:legacy_apparmor_migration: True
# after operator approval (reboot + relabel required).
