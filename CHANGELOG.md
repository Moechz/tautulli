# Changelog

All notable user-visible changes to the Tautulli TOS application package.

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
