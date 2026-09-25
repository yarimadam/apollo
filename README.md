# Apollo

> A self-hosted streaming stack for Stremio/Nuvio: addons, metadata, and the
> infrastructure to run them, all behind a single reverse proxy.

![Docker Compose](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/reverse%20proxy-traefik-24A1C1?logo=traefikproxy&logoColor=white)
![Self Hosted](https://img.shields.io/badge/self--hosted-yes-success)
![License](https://img.shields.io/badge/license-MIT-yellow)

Apollo bundles a [Stremio](https://www.stremio.com/)/[Nuvio](https://github.com/NuvioMedia)
streaming addon ([AIOStreams](https://github.com/Viren070/AIOStreams)) and a
metadata addon ([AIOMetadata](https://github.com/cedya77/aiometadata)) and an
account/addon manager ([SlickSync](https://github.com/slicknsliding/slicksync)) behind
[Traefik](https://traefik.io/traefik/), with [Portainer](https://www.portainer.io/)
for container management, [Redis](https://redis.io/) for caching, and
automated [restic](https://restic.net/) backups, orchestrated end-to-end with
[Task](https://taskfile.dev).

This is an opinionated setup, not a general-purpose template: **Tailscale is
mandatory**, not an optional extra. Portainer and the Traefik dashboard have
no public exposure path; they serve their own HTTPS (self-signed certs) on
ports 9443 and 8443, bound only to the host's Tailscale IP. There's no
fallback for running this without a tailnet.

## Features

- AIOStreams: unified streaming addon for Stremio/Nuvio clients
- AIOMetadata: metadata addon
- SlickSync: addon, user and credential management across Stremio/Nuvio
  accounts, with live Now Playing from AIOStreams' stream dashboard
- Traefik in front of the public sites, with real Let's Encrypt certs. Its
  routes live in one file, so it never gets the Docker socket
- Traefik's dashboard, reachable only over the tailnet at
  `https://<tailscale-ip>:8443/dashboard/`
- Portainer for container management, reachable only over the tailnet at
  `https://<tailscale-ip>:9443`
- Automated restic backup/prune/check jobs, covering every service's `.env`
  alongside its data volume; local by default, optionally offsite (e.g.
  Cloudflare R2)
- One `compose.yaml` per service, sharing an external Docker network
- Pinned image versions everywhere, no floating `latest` tags
- Hardened containers: all capabilities dropped (only what each image needs
  is added back), `no-new-privileges`, PID limits, read-only root filesystem
  for Traefik and Redis
- `task up` / `task down` for the whole stack or a single service

## Architecture

```
                         ┌──────────────┐
   Internet ─────────────▶   Traefik    │──────▶ AIOStreams (external)
                         │ (reverse     │──────▶ AIOMetadata (external)
                         │  proxy)      │──────▶ SlickSync (external)
                         └──────────────┘
                                │
                         apollo network
                                │
                    ┌───────────────────────┐
                    │  Redis  │  Backups     │
                    └───────────────────────┘

   Tailscale ────────────▶ Portainer :9443 (internal only)
   Tailscale ────────────▶ Traefik dashboard :8443 (internal only)
```

Every service lives in its own folder with its own `compose.yaml` and
`.env`, all attached to one external `apollo` Docker network. There's no
monolithic compose file; spin services up and down independently, or all
together.

Traefik additionally joins `apollo_edge`, an IPv6-enabled network that carries
its published ports. Docker then forwards IPv6 clients by kernel NAT instead
of through `docker-proxy`, so Traefik (and the addons behind it) see real client
addresses on IPv6 too. The addons stay IPv4-only, which keeps their outbound
traffic to debrid/usenet services on a single address.

## Services

| Service       | Folder         | Description                          | Exposure                    |
|---------------|----------------|---------------------------------------|------------------------------|
| `portainer`   | `portainer/`   | Docker management UI                  | Internal (Tailscale) only    |
| `traefik`     | `traefik/`     | Reverse proxy, automatic HTTPS         | External (dashboard: Tailscale only) |
| `aiostreams`  | `aiostreams/`  | Stremio/Nuvio streaming addon          | External                     |
| `aiometadata` | `aiometadata/` | Stremio/Nuvio metadata addon           | External                     |
| `slicksync`   | `slicksync/`   | Stremio/Nuvio account/addon manager    | External                     |
| `redis`       | `redis/`       | Cache shared by AIOStreams/AIOMetadata | Internal (apollo network)    |
| `backup`      | `backup/`      | restic backup / prune / check jobs     | n/a                           |

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev/installation/)
- [Tailscale](https://tailscale.com/), installed and running on the host:
  required, not optional. Portainer is only reachable over it.

### Installation

```sh
git clone <this-repo>
cd apollo
for d in */; do [ -f "$d.env.example" ] && cp "$d.env.example" "$d.env"; done
# fill in each */.env with your domains, IPs, and secrets
task up
```

Task creates the shared networks and brings every service up in the
right order.

### Usage

```sh
task up                  # start everything
task down                # stop everything
task up:aiostreams        # start a single service
task down:traefik         # stop a single service
task --list                # see all available tasks
```

## Configuration

Each service reads only its own `<service>/.env` (see the `.env.example`
next to it for the full, documented template), so every `compose.yaml` runs
on its own. Key things you'll want to set:

- `portainer/.env` `INTERFACE`: the host's Tailscale IP
  (`tailscale ip -4`); Portainer binds here only
- `traefik/.env` `INTERFACE`: the host's Tailscale IP; the dashboard
  binds here only
- `traefik/.env` `AIOSTREAMS_DOMAIN` / `AIOMETADATA_DOMAIN` /
  `SLICKSYNC_DOMAIN`: public hostnames for each service
- `traefik/.env` `CERT_RESOLVER`: `letsencrypt` in production (real certs,
  issued automatically), empty for Traefik's self-signed cert in local dev
- `backup/.env` `RESTIC_PASSWORD`: encrypts your backup repository
- `backup/.env` `RESTIC_REPOSITORY`: optional restic backend URL for offsite
  backups (e.g. Cloudflare R2); leave empty for local-only

A few values describe a connection between two services, so they must be
set to the same value in both files:

- Redis password: `redis/.env` `PASSWORD`, and `REDIS_PASSWORD` in
  `aiostreams/.env` and `aiometadata/.env`
- SlickSync's AIOStreams login: one `user:pass` entry of `aiostreams/.env`
  `AIOSTREAMS_AUTH`, and `slicksync/.env` `AIOSTREAMS_AUTH_USERNAME` /
  `AIOSTREAMS_AUTH_PASSWORD`
- Public URLs: `traefik/.env` domains and each app's own base URL

`.env` files are git-ignored, never commit them. The `.env.example` files
are the tracked, secret-free templates.

### Search engines

Every public response carries `X-Robots-Tag: noindex, nofollow, noarchive`.
There's no `robots.txt`: Traefik doesn't serve static files.

See [RECOVERY.md](RECOVERY.md) for restoring the stack onto a fresh server
from backup.

## License

[MIT](LICENSE)

## Acknowledgements

- [AIOStreams](https://github.com/Viren070/AIOStreams)
- [AIOMetadata](https://github.com/cedya77/aiometadata)
- [SlickSync](https://github.com/slicknsliding/slicksync)
- [Traefik](https://github.com/traefik/traefik)
- [Portainer](https://github.com/portainer/portainer)
