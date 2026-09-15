# Apollo

> A self-hosted streaming stack for Stremio — addons, metadata, and the
> infrastructure to run them, all behind a single reverse proxy.

![Docker Compose](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)
![Caddy](https://img.shields.io/badge/reverse%20proxy-caddy-1F88C0?logo=caddy&logoColor=white)
![Self Hosted](https://img.shields.io/badge/self--hosted-yes-success)
![License](https://img.shields.io/badge/license-MIT-yellow)

Apollo bundles a [Stremio](https://www.stremio.com/) streaming addon
([AIOStreams](https://github.com/Viren070/AIOStreams)) and a metadata addon
([AIOMetadata](https://github.com/cedya77/aiometadata)) behind
[Caddy](https://caddyserver.com/), with [Portainer](https://www.portainer.io/)
for container management, [Redis](https://redis.io/) for caching, and
automated [restic](https://restic.net/) backups — orchestrated end-to-end with
[Task](https://taskfile.dev).

## ✨ Features

- 🎬 **AIOStreams** — unified streaming addon for Stremio/Nuvio clients
- 🗂️ **AIOMetadata** — metadata addon, Redis-backed
- 🔒 **Automatic HTTPS** via Caddy, split internal (Tailscale-only) and
  external (public) routing
- 🐳 **Portainer** for at-a-glance container management, reachable only over
  your tailnet
- 💾 **Automated backups** — scheduled restic backup/prune/check jobs
- 📦 **Modular by design** — one `compose.yaml` per service, sharing a single
  external Docker network
- 🔖 **Pinned versions** — no floating `latest` tags, anywhere
- ⚙️ **One command up, one command down** — `task up` / `task down`

## 🏗️ Architecture

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
`.env` file. There's no monolithic compose file to wrangle — spin services up
and down independently, or all together.

## 📋 Services

| Service       | Folder         | Description                          | Exposure                  |
|---------------|----------------|---------------------------------------|----------------------------|
| `portainer`   | `portainer/`   | Docker management UI                  | Internal (Tailscale) only  |
| `caddy`       | `caddy/`       | Reverse proxy, automatic HTTPS         | Internal + external        |
| `aiostreams`  | `aiostreams/`  | Stremio/Nuvio streaming addon          | External                   |
| `aiometadata` | `aiometadata/` | Stremio metadata addon                 | External                   |
| `redis`       | `redis/`       | Cache backing AIOMetadata              | Internal (apollo network)  |
| `backup`      | `backup/`      | restic backup / prune / check jobs     | n/a                         |

## 🚀 Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (OrbStack or Docker Desktop)
- [Task](https://taskfile.dev/installation/)
- [Tailscale](https://tailscale.com/) for internal-only access

### Installation

```sh
git clone <this-repo>
cd apollo
cp .env.example .env   # fill in your domains, IPs, and secrets
task up
```

That's it — Task creates the shared `apollo` network and brings every service
up in the right order.

### Usage

```sh
task up                # start everything
task down               # stop everything
task up:aiostreams       # start a single service
task down:caddy          # stop a single service
task --list              # see all available tasks
```

## ⚙️ Configuration

All configuration lives in a single root `.env` file (see `.env.example` for
the full, documented template). Key things you'll want to set:

- `EXTERNAL_IP` / `INTERNAL_IP` — public vs. Tailscale-only interfaces
- `AIOSTREAMS_DOMAIN` / `AIOMETADATA_DOMAIN` — public hostnames for each addon
- `CADDY_EXTERNAL_TLS` — `tls internal` for local dev, empty for real
  Let's Encrypt certs in production
- `RESTIC_PASSWORD` — encrypts your backup repository

`.env` is git-ignored — never commit it. `.env.example` is the tracked,
secret-free template.

## 🗺️ Roadmap

- [ ] Production `.env` with real domains and Let's Encrypt certs
- [ ] Off-site backup target (Google Drive / S3 / B2) via restic
- [ ] Optional gluetun-based addon proxying

## 📄 License

[MIT](LICENSE)

## 🙏 Acknowledgements

- [AIOStreams](https://github.com/Viren070/AIOStreams)
- [AIOMetadata](https://github.com/cedya77/aiometadata)
- [Caddy](https://github.com/caddyserver/caddy)
- [Portainer](https://github.com/portainer/portainer)
