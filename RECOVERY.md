# Disaster Recovery

Restoring the full stack onto a fresh server after the original is lost.

This only works if the repo survived the server's loss: either
`RESTIC_REPOSITORY` was set to offsite storage (e.g. R2), or it was
local-only and you manually copied `backup/restic-repo/` somewhere else
yourself (another machine, external drive, etc.). A local-only repo that was
never copied off the server doesn't survive losing the server, since it's
on the same disk as everything else it backs up.

## Prerequisites on the new server

- Docker, Task, Tailscale installed and Tailscale authenticated (same as a
  normal install, see README).
- The bootstrap secrets, from a password manager (never only on the server
  itself): `RESTIC_PASSWORD`, and if using offsite storage also
  `RESTIC_REPOSITORY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
  Everything else comes back from the backup.

## Steps

1. Clone the repo:
   ```sh
   git clone <this-repo> apollo && cd apollo
   ```
   If restoring from a manually-copied local repo rather than offsite
   storage, also copy that directory to `apollo/backup/restic-repo/` now.

2. If the new server's Tailscale hostname differs from the old one, fix it
   before continuing, since `PORTAINER_DOMAIN` depends on it matching:
   ```sh
   tailscale up --hostname=apollo
   ```
   Remove or rename the old device in the Tailscale admin console first if
   it's still registered.

3. Pre-create the named volumes, empty. Don't start the app containers yet;
   restoring after they've initialized can conflict with the old data
   (`AIOSTREAMS_SECRET_KEY` in particular is tied to the restored configs):
   ```sh
   docker volume create portainer_data
   docker volume create caddy_data
   docker volume create aiostreams_data
   docker volume create aiometadata_data
   ```

4. Restore everything in one shot, using a throwaway container with the same
   mount layout the backup job used, so `restic restore --target /` drops
   files back where they were read from.

   **Offsite repo (R2/S3-compatible):**
   ```sh
   export RESTIC_REPOSITORY=... RESTIC_PASSWORD=... \
          AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...

   docker run --rm \
     -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
     -v portainer_data:/mnt/volumes/portainer \
     -v caddy_data:/mnt/volumes/caddy \
     -v aiostreams_data:/mnt/volumes/aiostreams \
     -v aiometadata_data:/mnt/volumes/aiometadata \
     -v "$(pwd)/restore-env:/mnt/volumes/env" \
     mazzolino/restic:1.8.2 restic restore latest --target /
   ```

   **Manually-copied local repo** (from step 1):
   ```sh
   export RESTIC_PASSWORD=...

   docker run --rm \
     -e RESTIC_REPOSITORY=/mnt/restic -e RESTIC_PASSWORD \
     -v "$(pwd)/backup/restic-repo:/mnt/restic:ro" \
     -v portainer_data:/mnt/volumes/portainer \
     -v caddy_data:/mnt/volumes/caddy \
     -v aiostreams_data:/mnt/volumes/aiostreams \
     -v aiometadata_data:/mnt/volumes/aiometadata \
     -v "$(pwd)/restore-env:/mnt/volumes/env" \
     mazzolino/restic:1.8.2 restic restore latest --target /
   ```

   Either way, this also drops the backed-up `.env` into
   `./restore-env/.env`.

5. Move `.env` into place:
   ```sh
   cp restore-env/.env .env && rm -rf restore-env
   ```

6. Update the values in `.env` that are inherently tied to the old host:
   - `EXTERNAL_IP`: the new server's public IP.
   - `PORTAINER_DOMAIN`: only correct if the new server's Tailscale hostname
     matches (step 2).

7. Bring the stack up:
   ```sh
   task up
   ```
   Caddy re-fetches certs as needed: Let's Encrypt for the external sites,
   its built-in Tailscale cert manager for Portainer. Both usually work
   immediately since `caddy_data` (holding prior cert state) was restored.

8. Re-apply what lives outside the repo, since none of it was backed up:
   - Provider firewall rules (allow 443/tcp, 80/tcp, 443/udp, 41641/udp
     inbound, deny the rest).
   - DNS: if `EXTERNAL_IP` changed, update `AIOSTREAMS_DOMAIN` /
     `AIOMETADATA_DOMAIN`'s A/AAAA records.

9. Verify:
   ```sh
   docker compose ps
   tailscale status
   curl -I https://<AIOSTREAMS_DOMAIN>
   curl -I https://<AIOMETADATA_DOMAIN>
   ```
   Confirm Portainer loads over the tailnet.
