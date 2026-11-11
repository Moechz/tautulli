# Changelog

All notable user-visible changes to the Tautulli TOS application package.

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
