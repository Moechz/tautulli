# Changelog

All notable user-visible changes to the Tautulli TOS application package.

## 2.19.1-3 — 2026-11-26

Remediation of the App Center review of 2.19.1-2 (x86_64: **F5** plus a failed
online-installation check; aarch64: **S11**, **S6**, **S9**, **V1**).

### Changed / fixed

- **S6 — no credential is shipped any more.** 2.19.1-2 seeded a fixed
  `admin` / `tautulli` account into `config.ini`. The package now contains no
  account at all: `src/entrypoint.sh` generates a random 16-character password on
  the very first start with Tautulli's own PBKDF2 parameters (sha256, 600000
  rounds), writes **only the hash** into `config/config.ini`, and writes the
  plain text to `config/initial-password.txt` with mode 600 in the app data
  folder (readable from the TOS file manager, not printable into the log).
  Once the stored hash no longer matches that file (the user changed the
  password), the file is deleted on the next start.
- **S11 — file permissions minimised.** The wrapper runs with `umask 077`,
  creates `/config`, `logs`, `cache` and `backups` with mode 700, and
  pre-creates `tautulli.db` as 600 before the s6 service manager (which runs with
  its own umask) can create it 644. Verified after a clean first start:
  `config.ini` 600, `initial-password.txt` 600, `tautulli.db*` 600,
  `logs/` 700.
- **V1 — root privilege.** On top of the pinned `user: "1000:1000"`, the service
  now drops every Linux capability (`cap_drop: [ALL]`) and sets
  `security_opt: [no-new-privileges:true]`. Measured in the running container:
  `uid=1000`, `CapEff 0000000000000000`, `CapBnd 0000000000000000`,
  `NoNewPrivs 1`. The upstream image declares no `USER` (that is what the
  detection sees), so `docs/ROOT-PRIVILEGE.md` records the analysis and the
  measurements, and explains why no root exemption is requested.
- **S9 — no issue text was provided** ("Review item S9", empty ISSUE). The
  common interpretations were audited against the package: no credential or
  token is printed to the log (the wrapper prints only the file location and
  Tautulli's own generated-password banner is never reached because the password
  already exists), the package contains no other secret, and the checksum of the
  reviewed package matches the platform record and the release assets. The
  audit is recorded here so the next review can verify it.
- **F5 / failed online install — the declared functionality is now what actually
  runs, and it is tested.** The description no longer promises a dashboard
  without Plex: it states that the web UI, settings, logs and notification setup
  work without Plex and that statistics need an existing Plex server. The first
  login is a documented, reproducible flow instead of an implicit one.
  `test/smoke.sh` drives the real core flow (login page → sign in with the
  generated credential → dashboard → settings page → API rejects unauthenticated
  calls → wrong password rejected) and is part of the release gate.

### Added

- `docs/ROOT-PRIVILEGE.md` — S11/V1 analysis with reproducible measurements.
- `test/smoke.sh` — functional smoke test for the core flow (base URL argument,
  non-zero exit when the app is unusable).
- `smoke.yml` — extra probes used by the pipeline's `smoke.py` gate.

### Unchanged

- Upstream image `linuxserver/tautulli:v2.19.1-ls252`, the host/container ports
  (8015 → 8181), the single data volume and the data behaviour.

## 2.19.1-2 — 2026-11-19

### Review remediation
- **C3** — privacy policy: `PRIVACY.md` is now a complete policy (scope, data
  stored locally, outbound traffic, retention, user rights, security, deletion
  channel, contact) and is linked from the package `help` field, the README and
  the release note.
- **C8** — third-party API disclosure: new table listing every endpoint
  (Plex Media Server, plex.tv, The Movie Database, TheTVDB, GitHub and the
  optional notification / image-hosting services), the data sent, the purpose
  and the destination region. Self-hosted alternatives (Gotify, ntfy, SMTP,
  webhooks) are listed as well.
- **F1** — installation failed (as reported by the review): not reproducible
  locally. Package layout, `config.ini` fields, `platform`/`id` matching and
  archive contents were re-checked against an existing package; the upstream
  image ships `curl` for the healthcheck; a clean dual-architecture rebuild
  passes the official self-test and an isolated staging run (container
  running/healthy, HTTP 303, uid 1000). The first-start grace period was
  extended to 90 s with 5 retries to tolerate slower NAS disks.

### Unchanged
- Upstream image `linuxserver/tautulli:v2.19.1-ls252`, host/container ports,
  the single data volume and the data behaviour.

## 2.19.1-1 — 2026-11-11

### Changed
- Upgraded to Tautulli 2.19.1 (`linuxserver/tautulli:v2.19.1-ls252`, Docker Hub,
  unmodified).
- First-run wrapper seeds a known admin account (`admin` / `tautulli`; change it
  immediately) so the login page is usable without reading container logs.
- Added `PRIVACY.md` and linked it from the package `help` field.
- Clarified the Plex requirement and the uninstall/data behaviour.

### Fixed (review remediation)
- **C10**: public repository, complete README (layout, security, privacy,
  uninstall) and package sources under `src/`.
- **C3**: privacy policy in the repository and in the package `help` field.
- **F1**: official `-i` install passes on a clean host; the only install failure
  observed was Docker network-pool exhaustion in the test environment
  (`all predefined address pools have been fully subnetted`), cleared by pruning
  unused networks.
- **F11**: data is confined to `DockerAppData/tautullidocker`; uninstall with data
  removal deletes it, a normal uninstall keeps it for reinstall.
- **F5/F7**: the app now has a usable first login (`admin` / `tautulli`); the
  login page and setup wizard were verified with a browser.
- **F9**: `restart: unless-stopped`; container restart and reinstall verified.
- **T1**: updated to the latest upstream image/build; remaining CVEs, if any, are
  in the upstream base image.
- **T3/V1**: no root process; compose `user: "1000:1000"`; no privileged mode,
  host network, Docker socket or `cap_add`; the image's default root is
  overridden.
- **V10/V5/V7**: x86_64 and aarch64 packages match the platform declarations; the
  app_id is unique; the published SHA-256 matches the uploaded package.
- **V12**: not applicable; Tautulli is a media statistics tool.

### Architectures
- x86_64: `tautullidocker_x86_64.tar.gz` (5896 B,
  `0edc38ce90af445842490cc20bebc05a63373d3f896aa097d1cc5f5c89ca9b5e`)
- aarch64: `tautullidocker_aarch64.tar.gz` (5897 B,
  `f844f4abe446c25a003e2617181a88d95187c9ef533b53dc88fa6362a36b6a98`)
- x86_64 has the full on-device E2E (14/14); aarch64 passes the official check
  and the platform validation (no ARM host available for a container E2E).

## 2.18.2-1 — 2026-11-08

### Added
- First release. Tautulli (`linuxserver/tautulli:v2.18.2-ls251`, Docker Hub official image, unmodified)
  packaged as a TOS 7 Docker application, published on port 8015 and running
  as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/tautullidocker/`.

### Architectures
- Dual-architecture release: `tautullidocker_x86_64.tar.gz` (4447 B, `45fbf2f1303dd2727461ce60bd97fc583a3f13f9deacf83882f996c607d35b82`) and
  `tautullidocker_aarch64.tar.gz` (4448 B, `b647462d76caa9a35bdcd3c8c22a77803187f6900dc2546febd576b1648a917d`), built by `scripts/build-dual.sh`.
  x86_64 has the full on-device E2E; aarch64 passes the official check and the
  platform validation (no ARM host available for a container E2E).
