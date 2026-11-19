# Privacy Policy — Tautulli for TerraMaster TOS 7

This policy describes how the **Tautulli** Docker application package
(`tautullidocker`) handles data when installed on your TerraMaster NAS.

- Package: `tautullidocker` (TOS 7 App Center, Docker application)
- Upstream software: [Tautulli](https://github.com/Tautulli/Tautulli) 2.19.1,
  shipped as the official `linuxserver/tautulli` Docker Hub image
- Publisher: Moechz
- Last updated: 2026-11-19

## 1. Scope

The application runs the official LinuxServer.io image unmodified, as a
non-root container (uid 1000). This policy covers the package, the wrapper
script it adds, and the default configuration. Plex Media Server, the upstream
Tautulli software and any notification service you configure have their own
policies; this document describes what *this package* and the local Tautulli
instance do.

## 2. Data stored on your NAS

Everything Tautulli needs is stored locally, under
`/Volume1/DockerAppData/tautullidocker/`, readable and writable only by the
application user (uid 1000):

| Data | Where | Why |
|---|---|---|
| Plex server URL and Plex token | `config/config.ini` | Connect to the Plex server you choose |
| Admin username and password hash | `config/config.ini` | Sign in to the Tautulli web UI |
| Play history, session and library statistics, user names | `config/tautulli.db` | Core functionality (the dashboard and reports) |
| Application settings and notification credentials you enter | `config/tautulli.db` | Remember your configuration |
| Logs, including generated credentials on an untouched upstream install | `config/logs/` | Operation and troubleshooting |
| Image and metadata cache | `config/cache/` | Speed up the UI; rebuilt automatically |

Nothing in this list is uploaded to the publisher or to TerraMaster. The
publisher operates no server that receives data from this application.

## 3. Data sent off your NAS

The package itself sends no telemetry, analytics, crash reports or usage data.
Outbound connections are made by Tautulli, and only to the endpoints listed in
section 4 — all of them either belong to you (your Plex server) or are
services you explicitly configure. When Tautulli talks to a service, the
request necessarily carries your NAS's public IP address and standard HTTP
metadata in addition to the payload listed below.

## 4. Third-party services and API endpoints (C8 disclosure)

Tautulli calls the following endpoints. "Always" means the feature is part of
normal operation; "optional" means it happens only if you enable or configure
it.

| Service | Example endpoint | Data sent | Purpose | Destination / region | When |
|---|---|---|---|---|---|
| Plex Media Server (yours) | `http(s)://<your-plex-host>:32400/...` | Plex token, API queries (sessions, metadata, users, libraries) | Read playback activity and library metadata | The server address you enter — your LAN or your own remote host | Always (core function) |
| Plex account services | `https://plex.tv/...` | Plex account/server identifiers, token validation request | Server discovery, token validation, "open in Plex" links | Plex (plex.tv), United States | When you connect a Plex account or use Plex-hosted features |
| The Movie Database (TMDB) | `https://api.themoviedb.org/3/...` | Movie/TV title names and external IDs | Poster/backdrop and metadata lookups | TMDB, United States | When metadata lookup is needed (e.g. posters, newsletters) |
| TheTVDB | `https://api4.thetvdb.com/v4/...` | Series names and external IDs | Series metadata and artwork | TheTVDB, United States | When series metadata lookup is needed |
| GitHub | `https://api.github.com/...`, `https://github.com/...` | Version string and request metadata (no personal data) | Check for Tautulli updates and release notes | GitHub (Microsoft), United States | On the update check (manual or scheduled) |
| Email (SMTP) | Your configured SMTP host | Notification text: media title, user name, timestamp | Email notifications and newsletters | The mail provider you configure | Optional, only if enabled |
| Discord | `https://discord.com/api/webhooks/...` | Notification text and, if enabled, an image URL | Chat notifications | Discord, United States | Optional, only if configured |
| Slack | `https://hooks.slack.com/services/...` | Notification text | Chat notifications | Slack (Salesforce), United States | Optional, only if configured |
| Telegram | `https://api.telegram.org/bot<token>/...` | Notification text | Chat notifications | Telegram, global (operator-dependent) | Optional, only if configured |
| Pushover | `https://api.pushover.net/1/messages.json` | Notification text | Mobile push notifications | Pushover, United States | Optional, only if configured |
| Gotify / ntfy | Your self-hosted server URL | Notification text | Self-hosted push notifications | The server you configure | Optional, only if configured |
| Generic webhooks | The URL you configure | JSON payload with the notification text | Integrate with your own automation | The host you configure | Optional, only if configured |
| Imgur / Cloudinary | `https://api.imgur.com/...`, `https://api.cloudinary.com/...` | Uploaded notification image | Host notification images when the Plex image URL is not reachable | Imgur / Cloudinary, United States | Optional, only if image hosting is enabled |

No data is sold, rented or shared for advertising. The publisher does not
receive any of the above. Tautulli also supports self-hosted endpoints
(Gotify, ntfy, webhooks, SMTP): in that case the data stays on infrastructure
you control.

## 5. Optional features that create outbound traffic

- **Notifications** (Discord, Slack, Telegram, Pushover, Gotify, ntfy, email,
  webhooks) — only for the agents you configure and enable.
- **Image hosting** (Imgur, Cloudinary) — only if you enable it for
  notification images.
- **Newsletters** — email is sent through the SMTP server you configure.
- **Update checks** — a request to GitHub that contains no personal data; it
  can be disabled in Tautulli's settings.
- **Metadata lookups** (TMDB, TheTVDB) — titles and external IDs only, never
  your Plex token or viewing history.

## 6. Retention

Data is kept for as long as the application is installed and you keep it. Play
history can be trimmed in Tautulli's settings (per-library retention) or
deleted from the UI. Logs rotate according to Tautulli's own log rotation.
Uninstalling the application with data removal, or deleting
`/Volume1/DockerAppData/tautullidocker/`, deletes everything stored locally.

## 7. Your rights

You control the data directly on the NAS:

- **Access / portability** — the SQLite database `config/tautulli.db` contains
  all history and settings; copy the `config/` folder for a complete export.
- **Rectification** — edit users, libraries and settings in the Tautulli UI.
- **Erasure** — delete individual history entries or users in the UI, or delete
  the data folder to remove everything.
- **Restriction** — disable any optional feature in section 5 to stop the
  corresponding outbound traffic.

Because the publisher never receives your data, there is nothing to request
from the publisher; all requests are handled locally by you.

## 8. Security measures

- The container runs as uid 1000 (non-root), without privileged mode, host
  networking, extra capabilities or access to the Docker socket.
- Data lives in a directory readable and writable only by that user.
- The package seeds a known first-login account (`admin` / `tautulli`); change
  the password immediately. The password is stored as a PBKDF2 hash.
- Secrets you enter (Plex token, notification tokens) are stored in the local
  database and are never sent to the publisher.
- The web UI is served over plain HTTP on your LAN; if you expose it to the
  internet, put it behind HTTPS (reverse proxy) and enable authentication.

## 9. Deletion channel

To delete all data: App Center → uninstall the application **and** remove
`/Volume1/DockerAppData/tautullidocker/`. There is no server-side copy to
delete, and the publisher holds no data about you.

## 10. Changes

Material changes to this policy are published in this file and noted in the
package changelog with the version that introduced them.

## 11. Contact

Open an issue at <https://github.com/Moechz/tautulli/issues>.
