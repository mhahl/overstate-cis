# overstate_cis — user guide

For operators who run CIS hardening and read the results. Deploying the
formula itself is covered in the [admin guide](admin-guide.md);
Overstate UI click-paths are in the [Overstate guide](overstate-guide.md).

## What this formula does

CIS Distribution Independent Linux v2.0.0 hardening for Fedora 44 and
openSUSE Tumbleweed / Leap 16.0, Salt 3008. One entrypoint,
`overstate_cis` (`init.sls:1`), fans out to packages, config
(SELinux, bootloader, network, logging, access, accounts, maintenance),
services, and a read-only `audit.sls`.

Two modes, controlled by pillar:

| Pillar | Effect |
|---|---|
| `overstate_cis:enforce: False` (default) | Audit-only. Only `audit.sls` runs. Nothing is changed. Safe to run anywhere, including production mid-day. |
| `overstate_cis:enforce: True` | Enforcement. Packages installed, configs managed, services masked. |
| `overstate_cis:level: 1` (default) | Level 1 controls only. |
| `overstate_cis:level: 2` | Level 2 controls additionally enabled, but each risky item still needs its own opt-in flag (`tmout_enable`, `umask_restrictive`, `usb_disable`, `audit_immutable`). |
| `overstate_cis:controls` (all `True`) | Per-control toggles. Set any key to `False` to turn that control off — the conflict-avoidance switch (see admin guide "Per-control toggles"). Layered on top of the level/opt-in gates above. |

Every state ID embeds its control (`1.6.1-selinux-enforcing-mode:` in
`selinux.sls:1`) plus a `# CIS x.y.z - Title` comment, so failures map
1:1 to `tests/goss/*.yaml`.

## Standard run (Salt CLI)

```sh
# 1. Render check — catches Jinja/YAML/pillar errors, changes nothing
salt-call --local state.show_sls overstate_cis

# 2. Read-only report — safe with test=True, runs only audit.sls by default
salt '*' state.apply overstate_cis.audit test=True

# 3. Enforce Level 1 on a canary first (see targeting below)
salt 'canary*' state.apply overstate_cis \
  pillar='{"overstate_cis": {"enforce": True, "level": 1}}'

# 4. Verify with goss (see tests/run-goss-podman.sh:1)
goss -g tests/goss/ validate
```

Promote canary → wave → fleet only when goss is green and the job
returns show no unexpected changes.

## Targeting

Use grains, never bare `*` for the first run:

```sh
salt -C 'os:Fedora and not osrelease:44' state.apply overstate_cis.audit test=True
salt -C 'osfinger:openSUSE*Leap*16*' state.apply overstate_cis.audit test=True
salt -C 'osfinger:openSUSE*Tumbleweed*' state.apply overstate_cis.audit test=True
```

Useful grains on these minions: `os`, `osfinger`, `os_family`
(`RedHat` on Fedora, `Suse` on openSUSE), `selinux:enforced`.

## Reading results

- **Highstate output** renders folded per minion in the job return;
  expand a minion to see state-by-state results. State IDs contain the
  CIS number, so `1.6.3-selinux-mode-enforcing` failing tells you
  exactly which control broke.
- **Audit job** (`overstate_cis.audit`) only reports: partition layout,
  `sestatus`/`getenforce`, insecure-service enablement, sysctl values,
  firewalld zone, rsyslog/auditd status, `sshd -T` effective options,
  sudo/cron modes, world-writable / unowned / SUID scans. It never
  fixes anything — hand its output to the admin for triage.
- **Goss** (`tests/goss/1-selinux-bootloader.yaml` … `6-maintenance.yaml`)
  asserts files, packages, services, and command output post-apply.
  L2-only checks skip unless `ENABLE_L2=1` is set, matching the
  pillar-gated states.

## Interpreting common outcomes

- `audit.sls` reports `cis.rules missing` → enforcement has not run yet
  (`enforce: False`), or `logging.sls` failed. Not an emergency.
- `sestatus` warns "no policy loaded" on Leap 16 → known gap: userspace
  present, targeted policy not yet configured. Install ran
  (`selinux-policy-targeted`), relabel + reboot pending. See admin guide.
- World-writable / SUID findings → manual review list, never auto-fixed
  by design (Docker overlays, k8s volumes, GUI caches break under
  auto-chmod). Do not script bulk fixes from the report.
- `firewall-cmd --get-default-zone` not `public` → pillar override
  `firewalld_default_zone` is set, or someone changed it by hand.
  The formula only sets it; it never flushes rules behind firewalld.

## Caveats

- SELinux, bootloader, and `audit -e 2` changes need a reboot to take
  full effect. Plan a maintenance window; the formula never reboots.
- Freshly migrated hosts (AppArmor → SELinux) need relabel + reboot
  before enforcing. SELinux booleans applied pre-relabel will not stick.
- Laptops/desktops: `disable_wireless: True` default masks
  `wpa_supplicant`; set `False` in pillar for WiFi machines before
  enforcing. GUI breakage from `umask 027` / `TMOUT` is why both are
  L2 opt-ins. If any control still conflicts with a workload, switch it
  off individually with `overstate_cis:controls:<name>: False` (all
  controls default on; keys listed in `pillar.example:1` and the admin
  guide).
- Disabling a control in goss runs: the goss files assert the
  default-enabled outcome, so a host with `controls.<name>: False`
  fails that section's checks. Run only the goss sections whose
  controls you left on, or treat the skipped ones as expected.
