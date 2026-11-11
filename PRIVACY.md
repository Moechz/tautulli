# Privacy Policy — Tautulli for TOS 7

Last updated: 2026-11-11

This policy covers the TOS application package `tautullidocker` (this repository)
and the local Tautulli instance it runs on your TerraMaster NAS.

## What data the app handles

- The Plex server URL and Plex token that you enter in the Tautulli setup wizard.
- Tautulli's own database, cache and logs: play history, library metadata, user
  names and application settings.
- All of it is stored on your NAS, under
  `/Volume1/DockerAppData/tautullidocker/`, readable only by the application
  user (uid 1000).

## Network connections

- The app connects to the Plex Media Server URL that you configure, in order to
  read its API. Nothing is sent anywhere else by this package.
- Tautulli may check GitHub for upstream updates; this is upstream behaviour and
  can be disabled in Tautulli's own settings.
- The package itself sends no telemetry, analytics or usage data to Moechz,
  TerraMaster, LinuxServer.io or any third party.
- The web interface is served over plain HTTP on your local network. No cloud
  service is involved.

## Data sharing

- No data is sold or shared by this package.
- The upstream Tautulli project and LinuxServer.io publish their own policies
  for their software and container images; this package runs the image
  unmodified and does not add any data collection.

## Retention and deletion

- Data stays on the NAS until you delete
  `/Volume1/DockerAppData/tautullidocker/` or uninstall the application with
  data removal in the TOS App Center.
- Uninstalling without data removal keeps the folder so a later reinstall can
  reuse the settings and history.

## Contact

- Package issues: <https://github.com/Moechz/tautulli/issues>
- Upstream project: <https://github.com/Tautulli/Tautulli>
