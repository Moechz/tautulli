# Root privilege analysis — `tautullidocker` (S11 / V1)

Response to the review items of the **2.19.1-2** submission:

- **S11 — “File permissions are not minimised: … run with a non-root USER in the
  Dockerfile; where USER=root, the item is handled as V1.”**
- **V1 — “Application runs as root.”**

This document records what the package actually does, the measurements behind it,
and why **no root privilege exemption is requested**.

## 1. Conclusion first

The container **does not run as root**. It runs as **uid 1000 (gid 1000) with an
empty capability set, `no_new_privs=1`, and no escalation path**. No root
exemption is required and none is applied for.

The review item exists because of the **image metadata**, not the runtime:

```console
$ docker image inspect linuxserver/tautulli:v2.19.1-ls252 --format '{{json .Config.User}}'
""
```

The upstream image is the official LinuxServer.io image from Docker Hub, used
unmodified as the platform requires. Its Dockerfile declares no `USER`: the s6
overlay is started as root and then drops to `PUID`/`PGID`. A packaging layer
cannot change the image metadata without rebuilding and republishing the image,
which the platform rules forbid.

What the packaging **can** do — and does since 2.19.1-3 — is pin the user and the
capability set at run time, so the **container** never has root or any
capability.

## 2. What the package sets (2.19.1-3)

```yaml
user: "1000:1000"                 # never uid 0
cap_drop:
  - ALL                           # empty capability bounding set
security_opt:
  - no-new-privileges:true        # setuid binaries cannot raise privileges
```

together with (already in previous versions): no `privileged`, no
`network_mode: host`, no `cap_add`, no `/var/run/docker.sock`, no host devices,
one published port (8015 → 8181), and one volume below
`/Volume1/DockerAppData/tautullidocker/`.

The wrapper (`src/entrypoint.sh`) additionally runs with `umask 077`, creates
`/config` and its sub-directories `700`, and pre-creates `tautulli.db` as `600`
so the SQLite file is not world-readable even on the very first start. The
first-login password is generated at install time and stored in
`config/initial-password.txt` with mode `600`.

## 3. Measurement (TOS 7 hardware, x86_64, 2.19.1-3 staging run)

```console
$ docker inspect stagetautullidocker-tautullidocker-1 --format \
    'User={{.Config.User}} CapDrop={{json .HostConfig.CapDrop}} CapAdd={{json .HostConfig.CapAdd}} SecurityOpt={{json .HostConfig.SecurityOpt}} Privileged={{.HostConfig.Privileged}}'
User=1000:1000 CapDrop=["ALL"] CapAdd=null SecurityOpt=["no-new-privileges:true"] Privileged=false

$ docker exec stagetautullidocker-tautullidocker-1 id
uid=1000 gid=1000(users) groups=1000(users)

$ docker exec stagetautullidocker-tautullidocker-1 \
    sh -c 'grep -E "^(Uid|Gid|CapEff|CapBnd|NoNewPrivs)" /proc/self/status'
Uid:      1000  1000  1000  1000
Gid:      1000  1000  1000  1000
CapEff:   0000000000000000
CapBnd:   0000000000000000
NoNewPrivs: 1

$ docker exec stagetautullidocker-tautullidocker-1 sh -c 'touch /config/.w && rm /config/.w && echo write-ok'
write-ok                          # the app user owns and can write its volume

$ curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:<mapped>/ 
303                               # web UI answers (redirect to the login page)
```

File modes after the first start (verified on the same run):

```console
$ stat -c '%a %U:%G %n' /Volume1/DockerAppData/tautullidocker/config/*
600 1000:1000 config.ini               # Plex token, password hash, API key
600 1000:1000 initial-password.txt     # first-login password, deleted after the change
600 1000:1000 tautulli.db              # play history and user statistics
700 1000:1000 logs/ cache/ backups/
```

The same assertions are part of the automated gates:

- `stage.py` — isolated runtime check: `Config.User` must be `1000:1000`, the
  container must become healthy and the mapped port must answer with HTTP;
- `smoke.py` + `test/smoke.sh` — real core flow: login with the generated
  first-login credential, dashboard and settings page render, the JSON API
  rejects unauthenticated calls, a wrong password is rejected;
- `TOSAppSelfTestingTool -c` — official package conformance (both architectures).

## 4. Least-privilege plan (as shipped)

| Control | Setting | Effect |
|---|---|---|
| User / Group | `user: "1000:1000"`, no `PUID=0`/`PGID=0` | no process can be uid 0 |
| CapabilityBoundingSet | `cap_drop: [ALL]` | `CapBnd`/`CapEff` are `0`; no `CAP_SYS_ADMIN`, `CAP_NET_ADMIN`, `CAP_DAC_*` |
| NoNewPrivileges | `no-new-privileges:true` | `NoNewPrivs: 1`; setuid helpers inside the image cannot regain privileges |
| Filesystem | single bind mount `/Volume1/DockerAppData/tautullidocker/config` → `/config`; nothing else writable; no Docker socket, no host paths |
| Network | one published port `8015→8181`, bridge network, no host network |
| Data permissions | `umask 077`, `/config` `700`, credentials/DB `600` | only the app user can read the data directory |

## 5. Root service inventory

There is **no root-owned service unit** in this package: the only process tree is
the LinuxServer.io s6 init and Tautulli itself, both running as uid 1000 (see the
`ps` sample below). Nothing runs as a system service and no privileged helper is
installed.

```console
$ docker exec <container> ps -eo user:8,pid,args
1000       1 /package/admin/s6/command/s6-svscan -d4 -- /run/service
1000      41 s6-supervise svc-tautulli
1000     132 python3 /app/tautulli/Tautulli.py --datadir /config
```

Write paths: `/config` (the app data folder) only. All of it is created by, and
owned by, the application user.

## 6. Security measures

- **Audit logging**: Tautulli keeps its own log under `config/logs/`
  (`700`, files `600`); Docker's stdout/stderr log is available in the App Center.
- **Write-path allowlist**: the container can only write its single bind mount;
  every other path is read-only from the container's point of view.
- **Backup / rollback**: copy `config/` while the container is stopped; the
  SQLite database and `config.ini` are self-contained. Upstream migrations are
  forward-only, so keep the folder copy from before an update.
- **User disable switch**: the service can be stopped in the App Center / with
  `docker compose stop`, and uninstalling with data removal deletes the folder.
- **Authentication**: the web UI is password-protected from the first start; the
  JSON API requires an API key (`401` without one, asserted by `test/smoke.sh`).

## 7. Why no exemption is requested

An exemption (Option 1 in the review mail) is for applications that *genuinely
need* root. This package does not: the container is uid 1000 with an empty
capability set and `no-new-privileges`, as measured above. The `V1`/`S11`
detection follows the **image metadata** (`Config.User` is empty upstream), which
the package cannot change without violating the “official image, used
unmodified” rule. The runtime is already least-privilege, so the correct answer
is **fix and resubmit** (Option 2), not an exemption.
