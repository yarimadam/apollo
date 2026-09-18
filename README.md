# Apollo

> A self-hosted streaming stack for Stremio/Nuvio: addons, metadata, and the
> infrastructure to run them, all behind a single reverse proxy.

![Docker Compose](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)
![Caddy](https://img.shields.io/badge/reverse%20proxy-caddy-1F88C0?logo=caddy&logoColor=white)
![Self Hosted](https://img.shields.io/badge/self--hosted-yes-success)
![License](https://img.shields.io/badge/license-MIT-yellow)

Apollo bundles a [Stremio](https://www.stremio.com/)/[Nuvio](https://github.com/NuvioMedia)
streaming addon ([AIOStreams](https://github.com/Viren070/AIOStreams)) and a
metadata addon ([AIOMetadata](https://github.com/cedya77/aiometadata)) behind
[Caddy](https://caddyserver.com/), with [Portainer](https://www.portainer.io/)
for container management, [Redis](https://redis.io/) for caching, and
automated [restic](https://restic.net/) backups, orchestrated end-to-end with
[Task](https://taskfile.dev).

This is an opinionated setup, not a general-purpose template: **Tailscale is
mandatory**, not an optional extra. Portainer has no public exposure path; it's
routed by its Tailscale MagicDNS name, and Caddy's built-in Tailscale cert
manager (via the local `tailscaled` socket) is what issues its TLS cert.
There's no fallback for running this without a tailnet.

## Features

- AIOStreams: unified streaming addon for Stremio/Nuvio clients
- AIOMetadata: metadata addon, Redis-backed
- Split TLS/routing via Caddy: public sites get real Let's Encrypt certs;
  Portainer is bound to a Tailscale-only listener and gets its cert from
  Caddy's built-in Tailscale cert manager
- Portainer for container management, reachable only over the tailnet
- Automated restic backup/prune/check jobs, covering `.env` alongside every
  service's data volume; local by default, optionally offsite (e.g.
  Cloudflare R2)
- One `compose.yaml` per service, sharing a single external Docker network
- Pinned image versions everywhere, no floating `latest` tags
- `task up` / `task down` for the whole stack or a single service

## Architecture

```
                         ┌──────────────┐
   Internet ─────────────▶    Caddy     │──────▶ AIOStreams (external)
                         │ (reverse     │──────▶ AIOMetadata (external)
   Tailscale ────────────▶  proxy)      │──────▶ Portainer (internal only)
                         └──────────────┘
                                │
                         apollo network
                                │
                    ┌───────────────────────┐
                    │  Redis  │  Backups     │
                    └───────────────────────┘
```

Every service lives in its own folder with its own `compose.yaml`, all
attached to one external `apollo` Docker network and sharing a single root
`.env` file. There's no monolithic compose file; spin services up and down
independently, or all together.

## Services

| Service       | Folder         | Description                          | Exposure                    |
|---------------|----------------|---------------------------------------|------------------------------|
| `portainer`   | `portainer/`   | Docker management UI                  | Internal (Tailscale) only    |
| `caddy`       | `caddy/`       | Reverse proxy, automatic HTTPS         | Internal + external          |
| `aiostreams`  | `aiostreams/`  | Stremio/Nuvio streaming addon          | External                     |
| `aiometadata` | `aiometadata/` | Stremio/Nuvio metadata addon           | External                     |
| `redis`       | `redis/`       | Cache backing AIOMetadata              | Internal (apollo network)    |
| `backup`      | `backup/`      | restic backup / prune / check jobs     | n/a                           |

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev/installation/)
- [Tailscale](https://tailscale.com/), installed and running on the host:
  required, not optional. Portainer's routing and TLS both depend on it.

### Installation

```sh
git clone <this-repo>
cd apollo
cp .env.example .env   # fill in your domains, IPs, and secrets
task up
```

Task creates the shared `apollo` network and brings every service up in the
right order.

### Usage

```sh
task up                  # start everything
task down                # stop everything
task up:aiostreams        # start a single service
task down:caddy           # stop a single service
task --list                # see all available tasks
```

## Configuration

All configuration lives in a single root `.env` file (see `.env.example` for
the full, documented template). Key things you'll want to set:

- `EXTERNAL_IP` / `INTERNAL_IP`: public vs. Tailscale-only interfaces
- `AIOSTREAMS_DOMAIN` / `AIOMETADATA_DOMAIN`: public hostnames for each addon
- `PORTAINER_DOMAIN`: Portainer's Tailscale MagicDNS name (e.g.
  `apollo.your-tailnet.ts.net`)
- `CADDY_EXTERNAL_TLS` / `CADDY_INTERNAL_TLS`: `tls internal` for local dev,
  empty in production (real certs, issued automatically: Let's Encrypt for
  the external sites, Caddy's Tailscale cert manager for Portainer)
- `RESTIC_PASSWORD`: encrypts your backup repository
- `RESTIC_REPOSITORY`: optional restic backend URL for offsite backups (e.g.
  Cloudflare R2); leave empty for local-only

`.env` is git-ignored, never commit it. `.env.example` is the tracked,
secret-free template.

See [RECOVERY.md](RECOVERY.md) for restoring the stack onto a fresh server
from backup.

## License

[MIT](LICENSE)

## Acknowledgements

- [AIOStreams](https://github.com/Viren070/AIOStreams)
- [AIOMetadata](https://github.com/cedya77/aiometadata)
- [Caddy](https://github.com/caddyserver/caddy)
- [Portainer](https://github.com/portainer/portainer)
