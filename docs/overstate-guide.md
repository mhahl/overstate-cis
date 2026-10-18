# overstate_cis with Overstate

Overstate is a web UI in front of your Salt master: accept keys, fire
jobs, apply states, watch returns by JID. Salt still does the work.
This page maps the CIS workflow onto Overstate screens. UI concepts
below (Jobs form, batches, conformity, Files sync, Pillar snapshots)
behave as described in the Overstate user guide; only the CIS values
are specific to this formula.

Assumes the formula is deployed as `salt-srv/salt/overstate_cis/`
(file roots) with pillar under `pillar/`, and `salt/top.sls` includes
`overstate_cis` (see admin guide setup). No custom `_modules/` ship
here, so **Sync modules** is never needed for this formula.

## 1. Onboard and accept minions

Minions page → Onboard minion wizard. Pick the Fedora or SUSE
distribution, enter the minion ID, run the generated script on the new
machine as root (it configures Salt failover across your master IPs).
The minion appears under Keys → Pending: compare the fingerprint
against `salt-call --local key.finger` on the minion, then Accept.
No auto-accept exists.

Group canaries on the Minions page: tick rows → New group (e.g.
`cis-canary`). Use the group target type on the job form so canary,
wave, and fleet runs hit exact member lists.

## 2. Files: publish the formula

Files page shows the Salt file roots (top files and SLS content).
Operators and admins get Edit; viewers never see it.

- First deploy lands via git, not the browser: clone/checkout the
  canonical states repo on the Repo tab (fresh deploys), or push the
  `overstate_cis/` tree upstream and use **Check for updates** →
  **Sync now** (fast-forward only; diverged checkouts refuse with the
  git reason). A changed pull refreshes the master fileserver, so
  applies see the new states at once — if the refresh warns, the sync
  still landed but minions may serve stale states until it succeeds.
- Small fixes can use **Edit** → Save on an SLS file: one local commit
  per file, authored by you. Saving never applies anything to minions.
  Admins **Push** upstream when ready (refuses on diverged branches,
  dirty trees, or missing credentials — sync first).
- Verify visibility: browse to `overstate_cis/init.sls` and
  `pillar.example` in the file browser before firing any job.

## 3. Pillar: configure, then snapshot

Overstate reads pillar and snapshots it; it never writes pillar.
Manage pillar in git (or your pillar store), then on the Pillar page:

1. Open a canary minion, confirm `overstate_cis: {enforce: False,
   level: 1}` renders.
2. **Capture** a snapshot — this is your pre-hardening baseline for
   the diff view ("what changed on this host last Tuesday").
3. After each phase (audit → L1 → L2), Capture again and diff any two
   snapshots side by side to prove only intended keys moved.

State applies and pillar browsing are separate abilities under scoped
RBAC: being allowed to apply `overstate_cis` does not open the Pillar
page. If the page is missing, ask your team lead for the grant.

## 4. Jobs: audit first, always

Jobs → New job has five parts: target + type, function, args, mode,
via. Presets fill common work (ping, highstate, dry-run highstate
`test=True`, state apply).

**Audit (report-only, default pillar):**

- Target: grain `osfinger:openSUSE*` or glob `canary*`; type grain/glob.
- Function: `state.apply`. Args: `overstate_cis.audit`.
- Mode async (watch returns land by JID on the detail page) or sync.
- The state-apply review step lists the SLS about to be enforced,
  rendered on the first matched minion with an SLS preview — advisory
  only; if rendering fails it says so and firing stays available.
- Detail page: returns fold per minion with summary first; Raw JSON
  stays available. **Sync** pulls latest master state on demand.

Prefer the dry-run preset (`test=True`) for the first audit so even
`cmd.run` reporters declare intent before executing.

**Enforce L1 on the canary group:**

- Same form, target type group → `cis-canary`, function
  `state.apply`, args `overstate_cis`, plus a pillar override for the
  run: `{"overstate_cis": {"enforce": true, "level": 1}}`
  (Orchestrate runner also accepts a pillar-override JSON field).
- Destructive-function confirm (retype the target) may trigger for
  `state.apply` depending on site policy — type the group target to
  prove aim.
- Watch the detail page; expand the canary minion to see
  `<cis-id>-<slug>` state results. Each return links back to its minion.

**Roll out in waves:** switch batch mode from off to a wave size
(count or percent) with a stop-after-failures limit. The run pins
matching minions from inventory, executes one job per wave, and stops
early at your failure limit. **Stop batch** cancels between waves.
Save the finished form via **save as** (`cis-audit-l1`,
`cis-enforce-l1`, `cis-enforce-l2`) so routine re-runs are one click
from the Saved tab.

## 5. States and conformity: watch the formula

States page verdicts per minion: ok (last highstate clean), drifted
(changes/failures), unknown (no result yet), unreachable (no return
before ageing out).

Add `overstate_cis` (and optionally `overstate_cis.audit`) to watched
states: with a non-empty watch list a minion is ok only if every
watched file came back clean; un-narrowable returns carry a **partial**
badge. **Recompute** replays stored state-job returns without running
anything — a backfill after importing history, not the normal path.
The minion detail States tab shows the last stored run first with a
**Refresh from minion** live-compare beside it.

## 6. Schedules: daily audit, never daily enforce

Schedules are Salt's built-in cron on the minion. Add on a
representative minion, then replicate:

- `cis-daily-audit`: function `state.apply`, job args
  `overstate_cis.audit`, interval 1 day, enabled. Recurring audit is
  safe (read-only reporters).
- Do not schedule enforcement. Re-apply on purpose from Jobs with a
  fresh SLS preview and batch gate.

## 7. Mine, Events, Reactor

This formula publishes nothing to the Salt Mine and defines no beacons
(beacon definitions live in pillar; the Beacons tab toggles only
minion-local beacons). Mine page usage is limited to standard facts
(`network.ip_addrs`) during targeting triage.

Events viewer (job/auth/minion/key/runner families, last 50 per stream
for 60 s — open the stream before firing) is useful while watching a
wave land. Reactor auto-remediation on CIS drift is deliberately out of
scope: reactor SLS runs with master privileges fleet-wide, so wire it
only if your site accepts that blast radius, and record any live
mapping into the persisted `reactor:` stanza (Master Settings, admins
only) or a restart loses it.

## 8. Roles, service accounts, audit trail

- Ladder: viewers see everything and change nothing (no Edit, no Run);
  operators run jobs, manage groups/schedules, sync files; admins add
  users/settings/Master Settings. Buttons above your grant do not
  render, and the server rejects forged requests.
- Scoped sites: team roles on a minion slice; a `*` target runs on
  your minions only. State apply vs pillar-read vs file-edit are
  separate grants — missing pages mean missing scope, not a bug.
- CI: service accounts with Bearer tokens call `POST /api/jobs/run`
  pinned to a saved job (e.g. the saved `cis-audit-l1`) for the goss
  pipeline; unpinned read-class calls allowed per token. Rate-limited,
  no cookies. Prefer this over shared human logins for automation.
- Every save, sync, push, fire, kill, and refusal lands in the audit
  trail — cite JIDs and file revisions in change tickets.

## 9. End-to-end checklist (Overstate)

1. Keys accepted, `cis-canary` group saved.
2. Files synced — `overstate_cis/init.sls` browsable.
3. Pillar captured (baseline snapshot).
4. Audit job fired (`state.apply overstate_cis.audit`, dry-run preset
   first), returns green, JID recorded.
5. L1 enforced on canary via group target + pillar override, goss
   (`tests/goss/`, `ENABLE_L2` unset) green.
6. Batch wave rollout with failure gate; Saved jobs stored.
7. Watched state `overstate_cis` added; conformity ok.
8. Daily audit schedule registered; pillar re-captured.
9. L2 only in a window: `level: 2` + per-flag opt-ins, canary first,
   `ENABLE_L2=1` goss green before fleet.
