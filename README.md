# tautulli-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [Tautulli](https://github.com/linuxserver/docker-tautulli).

## What this is

A four-file TOS Docker application archive (`tautullidocker.tar.gz`) that installs
Tautulli on TOS 7 through the App Center:

- `config.ini` — TOS application metadata (`application_type: docker`, id `tautullidocker`)
- `tautullidocker.lang` — 23-language superset (TOS requires 14)
- `tautullidocker.svg` — application icon (1724 bytes, 4 SVG elements)
- `docker-compose.yml` — one service, image `linuxserver/tautulli:v2.18.2-ls251`

## How it works

| | |
|---|---|
| Container image | `linuxserver/tautulli:v2.18.2-ls251` (Docker Hub, used unmodified) |
| Open | `http://<NAS-IP>:8015/` (container port 8181) |
| Runs as | non-root, `user: "1000:1000"` |
| Persistent data | `/config` → `/Volume1/DockerAppData/tautullidocker/config` |
| Logs | `docker logs tautullidocker` (stdout/stderr) |

`config` holds `config.ini`, `tautulli.db` and the cache; copying it is a complete backup.

## Design highlights

- **Non-root.** `user: "1000:1000"`; verified on real hardware (the container reports uid 1000).
- **Fixed image tag, never `:latest`**, Docker Hub only, no `privileged`, no `network_mode: host`, and no Docker socket, no `cap_add`.
- **Health check** probing the service on container port 8181.
- **Deterministic build**: GNU tar with uid/gid 0 and zeroed timestamps, gzip without a timestamp, plus the review-standards self-check above.
- **Runs as a non-root container.** Verified on real hardware as uid 1000; the upstream image starts unprivileged.
- **One volume.** The database, settings and cache are all below `/config`; no other host path is written.
- **Health check** probes the web UI on container port 8181 (it answers with a redirect to the login page).
- **Fixed image tag, never `:latest`**, Docker Hub only, no `privileged`, no `network_mode: host`, no Docker socket, no `cap_add`.

## Runtime file manifest

Everything the application writes on the NAS lives inside its own data
directory; the container-internal `/tmp` is discarded with the container. The
table lists what is created and how it behaves. Nothing else is written.

| Path | Purpose | Created when | Growth bound | Lifecycle |
|---|---|---|---|---|
| `config/config.ini` | database path, Plex connection and UI settings | first start | small | never overwritten; back it up |
| `/Volume1/DockerAppData/tautullidocker/config` | Tautulli application data (everything the container writes outside /tmp) | on first start / on demand | bounded by your own data | persistent; kept on uninstall unless you ask to delete it |

## Architectures

The TOS store takes one package per architecture. This release provides both,
built from the same sources by `scripts/build-dual.sh`:

| Architecture | Package | Size | SHA-256 |
|---|---|---|---|
| x86_64 | `tautullidocker_x86_64.tar.gz` | 4447 B | `45fbf2f1303dd2727461ce60bd97fc583a3f13f9deacf83882f996c607d35b82` |
| aarch64 | `tautullidocker_aarch64.tar.gz` | 4448 B | `b647462d76caa9a35bdcd3c8c22a77803187f6900dc2546febd576b1648a917d` |

The x86_64 package was verified with the full on-device E2E; the aarch64 package
passes the official `TOSAppSelfTestingTool -c` check and the developer platform's
automated validation (no ARM host was available for a container E2E).

## Build

```bash
scripts/build.sh                  # -> out/tautullidocker.tar.gz + .sha256
scripts/build.sh 2.18.2-2   # packaging iteration bump
scripts/build.sh 2.18.2-1 aarch64
```

The build stages the four files, substitutes the version/platform placeholders,
removes CRLF/BOM/AppleDouble, then runs
`tools/verify.py`, a review-standards self-check (archive layout, JSON validity,
required fields, 14+ language coverage, version consistency, Docker-Hub-only
images, fixed tag, reserved/recommended host ports, non-root user, per-service
healthcheck/TZ/restart, data path below the application data root, never the
`/Volume*` wildcard, comment-free sequence blocks, `x-app-meta` position, no
literal secrets and the SVG size/element limits).

## Local verification

```bash
./TOSAppSelfTestingTool -c out/tautullidocker.tar.gz   # official spec check
bash test/install-and-verify.sh                  # on-device E2E (needs root)
```

> Docker applications cannot be side-loaded through the App Center's manual
> install page (it accepts `.deb` only); the official self-testing tool's `-i`
> mode or `docker compose` are the only ways to install one for testing.

## Store submission checklist

1. Public GitHub repo (code + README only).
2. Release **tag `v2.18.2-1`**, assets `tautullidocker.tar.gz` +
   `tautullidocker.tar.gz.sha256` (Docker asset naming: `<app_id>.tar.gz`, **no
   platform suffix**).
3. Developer platform → Add Application: ID `tautullidocker`, package type Docker,
   repository URL, architecture `x86_64`.
4. Version Management → Add Version `2.18.2-1` → automated validation → review.

## License / branding

Tautulli is distributed by its upstream authors under **GPL-3.0-only**. The container image is the official image from Docker Hub (`linuxserver/tautulli:v2.18.2-ls251`) and is used unmodified; no upstream source code is redistributed here. This packaging is an independent community submission by Moechz and is not affiliated with the upstream project or TerraMaster.

## Limitations

Plex Media Server is not included; Tautulli only reads its API and needs a reachable Plex server.
The page is plain HTTP on the LAN; use a TLS reverse proxy before exposing it to the internet.
Docker applications cannot be upgraded in place in the App Center: updating means uninstalling and reinstalling, which keeps the data folder.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
