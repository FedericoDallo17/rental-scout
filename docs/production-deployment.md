# Production deployment on one Hetzner VM

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
