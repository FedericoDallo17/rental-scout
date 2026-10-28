# Automatic production deployment

Production is the Coolify service `roryn8zi32hwqly5lyqguuin` on
`167.233.115.254`, serving <https://timbre.dallo.dev>. Coolify manages the
existing `web`, `job`, and PostGIS containers, networks, secrets, and volumes.

`homes.dallo.dev` permanently redirects to `https://timbre.dallo.dev`, preserving
the path and query string. Both domains use proxied A records in Cloudflare.
The canonical domain and `APP_HOST` are saved in Coolify. The old-domain
redirect is a Traefik file-provider configuration: install
`config/proxy/homes-redirect.yml` at
`/data/coolify/proxy/dynamic/rental-scout-homes-redirect.yaml` on the server.

Every push to `main` runs `.github/workflows/deploy.yml`:

1. Build the production Dockerfile for `linux/amd64` and push
   `ghcr.io/federicodallo17/rental-scout-lite:<commit SHA>` using the workflow's
   temporary `GITHUB_TOKEN` with package write permission.
2. Connect using a dedicated SSH key restricted to `script/deploy-production`.
   It accepts only a 40-character commit SHA; shell access and forwarding are disabled.
3. Pull the image, update both application image references in Coolify and its
   generated Compose configuration, and recreate only `web` and `job`.
4. Verify internal and public `/up` endpoints and that the job container stays
   running without restarts. Restore the previous image if deployment fails.

The database container is not recreated. Rails' entrypoint runs `db:prepare`;
image rollback does not undo database migrations, so use backwards-compatible
migrations. Deploys are serialized in Actions and by a server lock. The build
must succeed before deployment starts. Runs are visible under the repository's
**Actions → Deploy production**; `workflow_dispatch` can redeploy a selected ref.

## GitHub integration

The reusable GitHub App `coolify-federicodallo17` is installed for all current
and future repositories in `FedericoDallo17` and connected to Coolify. It has
read access and webhooks, with previews and Actions runner management disabled.
It is available for additional repository-based Coolify applications. This
existing Compose service deploys through the Actions workflow above.

## Server bootstrap and credentials

The installed helpers are root-owned:

- `/usr/local/lib/rental-scout/deploy-production` from `script/deploy-production`
- `/usr/local/lib/rental-scout/deploy-production.php` from `script/deploy-production.php`

After changing either helper, install it on the server before using the new
version. The PHP helper uses the existing Coolify application's bootstrap and
models; verify it after upgrading Coolify.

Repository Actions secrets:

- `DEPLOY_SSH_KEY`: dedicated Ed25519 private key.
- `DEPLOY_KNOWN_HOSTS`: host key copied from the operator's already-trusted
  `known_hosts`; the runner enforces strict host key checking.

The corresponding public key in `deploy`'s `authorized_keys` uses:

```text
restrict,command="sudo -n /usr/local/lib/rental-scout/deploy-production \"$SSH_ORIGINAL_COMMAND\"" ssh-ed25519 <public key>
```

Rails and database secrets remain on the server. No Coolify API token or
registry PAT is stored in Actions. The server's existing registry login pulls
the image. GitHub Actions must have write access to the GHCR package.

## Manual recovery

Inspect the failed Actions run, then deploy a known-good immutable image:

```sh
ssh deploy@167.233.115.254 'sudo /usr/local/lib/rental-scout/deploy-production FULL_40_CHARACTER_COMMIT_SHA'
```

Coolify's service page reflects the last deployed image for both roles.
Normal deploys do not restart the database or change volumes.

## Transactional email (Resend)

Password recovery uses authenticated SMTP with required TLS. Configure a Resend
Free account, verify `timbre.dallo.dev` using the DNS records returned by Resend,
and create a sending API key restricted to that domain. Disable click tracking
for authentication mail so reset links are not rewritten by a tracking service.

Persist these settings in Coolify's Compose configuration for **both** `web`
and `job` (service environment keys alone are not automatically passed into
Compose containers):

```text
SMTP_ADDRESS=smtp.resend.com
SMTP_PORT=587
SMTP_USERNAME=resend
SMTP_PASSWORD=<Resend API key, kept only in Coolify secrets>
MAIL_FROM=Timbre <notifications@timbre.dallo.dev>
APP_HOST=timbre.dallo.dev
APP_PROTOCOL=https
```

Port 587 requires STARTTLS and peer certificate verification. Providers using
implicit TLS can instead set `SMTP_SSL=true` and `SMTP_PORT=465`. Connection and
read timeouts are 10 seconds. Missing SMTP credentials fail configuration when
an SMTP server is specified; credentials are never needed for image builds.

Until a provider is configured, delivery raises an explicit configuration error
without attempting localhost SMTP or pretending mail was sent. Recovery shows a
translated retry message with HTTP 503 for missing configuration and SMTP,
network, TLS or timeout failures. Once the settings are saved, recreate `web`
and `job`, check their mail configuration without printing secrets, and verify
the verified-domain state plus an actual recovery request using an explicitly
authorized recipient. Never log the recovery token or message body.

Devise and application mail share `MAIL_FROM`. Recovery messages use the
account's saved language, independent of the signed-out browser language.
Registration confirmation and email/password-change notifications are not
enabled by the current User model; property alerts use Web Push/Pushover, not SMTP.

---

# Original Kamal bootstrap reference

The following describes the original setup. Current production uses the
Coolify/Actions deployment above; `config/deploy.yml` is retained as a reference.

This deployment runs the Rails web process, one Solid Queue worker, and
PostgreSQL/PostGIS on a single host. It is intended for the initial low-traffic
pilot. PostgreSQL is not exposed publicly.

## 1. Create the server

Create an x86 Hetzner Cloud VM with 2 shared vCPUs, 4 GB RAM, Ubuntu 24.04, and
Hetzner backups enabled. Attach an SSH key. This initial configuration is
accessed directly through the server's public IPv4 address.

Create a Cloud Firewall allowing inbound TCP 22 from an administrator IP and
TCP 80/443 from anywhere. Do not allow inbound 3000 or 5432.

Log in as root once and prepare the deploy account and backup directory:

```sh
adduser --disabled-password --gecos "" deploy
usermod -aG sudo deploy
install -d -o deploy -g deploy /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
install -d -o 1000 -g 1000 /var/backups/rental-scout-lite
```

Give `deploy` passwordless sudo for Docker installation, or install Docker
yourself and add `deploy` to the `docker` group. Kamal's first setup needs to
install Docker when it is absent.

Adding 2 GB of swap is useful protection during image replacement:

```sh
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

## 2. Configure the repository

Edit `config/deploy.yml` and replace every `YOUR_*` value and the example sender
address. Use the server's public IPv4 address for every `YOUR_SERVER_IP`
occurrence. The registry image name must be lowercase.

Copy the secrets template and fill it locally:

```sh
cp .kamal/secrets-example .kamal/secrets
chmod 600 .kamal/secrets
```

Use the contents of `config/master.key` for `RAILS_MASTER_KEY`, a fine-grained
GitHub token with package write/read access for `KAMAL_REGISTRY_PASSWORD`, and
a freshly generated long value for `DB_PASSWORD`. The secrets file is ignored
by Git. Keep `POSTGRES_PASSWORD=$DB_PASSWORD` so Rails and PostgreSQL receive
the same password.

Install Kamal on the operator machine using the current Kamal 2 release:

```sh
gem install kamal
```

## 3. First deployment

Validate configuration, boot Postgres, then deploy Rails:

```sh
kamal config
kamal accessory boot db
kamal setup
```

The Postgres initialization file creates the primary, cache, queue, and cable
databases on the first accessory boot. It only runs for an empty Postgres
volume. Rails runs `db:prepare` when the web container starts.

Verify the public health endpoint and both roles:

```sh
curl --fail http://SERVER_IP/up
kamal app details
kamal accessory details db
kamal app logs --roles web
kamal app logs --roles job
```

## 4. Backups

`script/backup-postgres` writes custom-format dumps for all four databases to
`/var/backups/rental-scout-lite` on the host and retains seven days by default.
Run it once and verify that four non-empty files appear:

```sh
kamal app exec --reuse 'script/backup-postgres'
ssh deploy@SERVER_IP 'ls -lh /var/backups/rental-scout-lite'
```

Schedule the command nightly from a trusted operator or CI runner. A local dump
does not protect against loss of the VM: copy the directory to a Hetzner Storage
Box, S3-compatible object storage, or another off-host destination after every
successful run. Keep Hetzner VM backups enabled as a second recovery mechanism.

Test a restore before inviting users. Example for a disposable database:

```sh
createdb rental_scout_restore_test
pg_restore --exit-on-error --no-owner --dbname=rental_scout_restore_test FILE.dump
```

## 5. Operations

Deploy with `kamal deploy`. Watch RAM, disk usage, the `/up` endpoint, failed
Solid Queue jobs, and the age of the latest successful scraping run. Upgrade
the VM only if memory remains above roughly 80%, swap is used continuously, or
hourly scraper jobs overlap.

Before launch, test every scraper from the VM. Property sites can treat a
datacenter IP differently from a development connection.

## Adding a domain later

Point the domain's DNS record at the VM, set `proxy.ssl` to `true`, add the
domain as `proxy.host`, set `APP_HOST` to the domain, and change
`RAILS_ASSUME_SSL`, `RAILS_FORCE_SSL`, and `APP_PROTOCOL` to `true`, `true`, and
`https`. A subsequent `kamal deploy` will enable automatic TLS.
