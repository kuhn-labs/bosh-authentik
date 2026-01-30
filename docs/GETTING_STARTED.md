# Getting Started with Authentik BOSH Release

This guide walks you through deploying [authentik](https://goauthentik.io/) on BOSH from scratch.

## What is Authentik?

Authentik is an open-source Identity Provider (IdP) that provides:

- **Single Sign-On (SSO)** via SAML 2.0 and OAuth2/OIDC
- **LDAP directory services** for legacy application integration
- **RADIUS authentication** for network devices
- **Reverse proxy authentication** for protecting applications
- **Multi-factor authentication (MFA)**
- **User management and self-service**

## Prerequisites

Before you begin, ensure you have:

- A running BOSH Director (v270+)
- Access to upload releases and deploy
- A cloud-config configured with VM types, networks, and disk types
- Ubuntu Jammy stemcell uploaded

### Verify Your Environment

```bash
# Check BOSH CLI
bosh --version

# Check director connection
bosh env

# List stemcells (should include ubuntu-jammy)
bosh stemcells

# View cloud-config
bosh cloud-config
```

## Step 1: Clone the Release

```bash
git clone https://github.com/your-org/bosh-authentik.git
cd bosh-authentik
```

## Step 2: Download Required Blobs

### Automatic Downloads

Run the helper script to download Python and its dependencies:

```bash
./scripts/download-blobs.sh
```

This downloads:
- Python 3.12.4
- setuptools
- pip

### Manual Downloads

You need to manually download the authentik application and outpost binaries.

#### Option A: Download Pre-built Assets (Recommended)

Download from the [authentik GitHub releases](https://github.com/goauthentik/authentik/releases):

```bash
AUTHENTIK_VERSION="2025.12.1"

# Create directories
mkdir -p blobs/authentik/vendor
mkdir -p blobs/outposts/{ldap,radius,proxy}

# Download outpost binaries
cd blobs/outposts
curl -L -o ldap/authentik-ldap_linux_amd64 \
  "https://github.com/goauthentik/authentik/releases/download/version%2F${AUTHENTIK_VERSION}/authentik-ldap_linux_amd64"
curl -L -o radius/authentik-radius_linux_amd64 \
  "https://github.com/goauthentik/authentik/releases/download/version%2F${AUTHENTIK_VERSION}/authentik-radius_linux_amd64"
curl -L -o proxy/authentik-proxy_linux_amd64 \
  "https://github.com/goauthentik/authentik/releases/download/version%2F${AUTHENTIK_VERSION}/authentik-proxy_linux_amd64"
cd ../..
```

#### Option B: Build from Source

```bash
AUTHENTIK_VERSION="2025.12.1"

# Clone authentik
git clone https://github.com/goauthentik/authentik.git /tmp/authentik
cd /tmp/authentik
git checkout "version/${AUTHENTIK_VERSION}"

# Download Python dependencies as wheels
pip download -d wheels -r requirements.txt -r requirements-dev.txt

# Copy wheels to blobs
cp -r wheels/* /path/to/bosh-authentik/blobs/authentik/vendor/

# Create source tarball
tar czf /path/to/bosh-authentik/blobs/authentik/authentik-${AUTHENTIK_VERSION}.tar.gz \
  --exclude='.git' \
  --exclude='web/node_modules' \
  .

# Build frontend
cd web
npm ci
npm run build
tar czf /path/to/bosh-authentik/blobs/authentik/web-dist.tar.gz dist/
```

## Step 3: Add Blobs to the Release

```bash
cd /path/to/bosh-authentik

# Python runtime
bosh add-blob blobs/python/Python-3.12.4.tar.xz python/Python-3.12.4.tar.xz
bosh add-blob blobs/python/setuptools-*.tar.gz python/setuptools-70.0.0.tar.gz
bosh add-blob blobs/python/pip-*.tar.gz python/pip-24.0.tar.gz

# Authentik application
bosh add-blob blobs/authentik/authentik-2025.12.1.tar.gz authentik/authentik-2025.12.1.tar.gz
bosh add-blob blobs/authentik/web-dist.tar.gz authentik/web-dist.tar.gz

# Python dependencies (wheels)
for wheel in blobs/authentik/vendor/*.whl; do
  bosh add-blob "$wheel" "authentik/vendor/$(basename $wheel)"
done

# Outpost binaries
bosh add-blob blobs/outposts/ldap/authentik-ldap_linux_amd64 outposts/ldap/authentik-ldap_linux_amd64
bosh add-blob blobs/outposts/radius/authentik-radius_linux_amd64 outposts/radius/authentik-radius_linux_amd64
bosh add-blob blobs/outposts/proxy/authentik-proxy_linux_amd64 outposts/proxy/authentik-proxy_linux_amd64
```

## Step 4: Create and Upload the Release

```bash
# Create a dev release
bosh create-release --force

# Upload to director
bosh upload-release
```

## Step 5: Upload Dependencies

```bash
# BPM release (required for process management)
bosh upload-release https://bosh.io/d/github.com/cloudfoundry/bpm-release

# PostgreSQL release (or use external database)
bosh upload-release https://bosh.io/d/github.com/cloudfoundry/postgres-release
```

## Step 6: Deploy

### Basic Deployment

```bash
bosh -d authentik deploy manifests/authentik.yml
```

### With Custom SMTP Settings

```bash
bosh -d authentik deploy manifests/authentik.yml \
  -v smtp_host=smtp.example.com \
  -v smtp_port=587 \
  -v smtp_from=authentik@example.com
```

### With External PostgreSQL

```bash
bosh -d authentik deploy manifests/authentik.yml \
  -o operations/use-external-postgres.yml \
  -v postgres_host=my-postgres.example.com \
  -v postgres_user=authentik \
  -v postgres_password=secretpassword \
  -v postgres_database=authentik
```

## Step 7: Initial Setup

1. Get the deployment IP:

```bash
bosh -d authentik instances
```

2. Open your browser and navigate to:

```
http://<instance-ip>:9000/if/flow/initial-setup/
```

3. Create your admin account by following the setup wizard.

4. Log in and start configuring authentik!

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     BOSH Deployment                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────────────────────┐   │
│  │   PostgreSQL    │  │          Authentik VM           │   │
│  │                 │  │  ┌───────────────────────────┐  │   │
│  │  - Database     │◄─┼──│   authentik-server        │  │   │
│  │  - User data    │  │  │   (Gunicorn + Uvicorn)    │  │   │
│  │  - Sessions     │  │  │   Port: 9000 (HTTP)       │  │   │
│  │                 │  │  │   Port: 9443 (HTTPS)      │  │   │
│  └─────────────────┘  │  └───────────────────────────┘  │   │
│                       │  ┌───────────────────────────┐  │   │
│                       │  │   authentik-worker        │  │   │
│                       │  │   (Background tasks)      │  │   │
│                       │  └───────────────────────────┘  │   │
│                       │  ┌───────────────────────────┐  │   │
│                       │  │   Outposts (optional)     │  │   │
│                       │  │   - LDAP  (Port 3389)     │  │   │
│                       │  │   - RADIUS (Port 1812)    │  │   │
│                       │  │   - Proxy (Port 9080)     │  │   │
│                       │  └───────────────────────────┘  │   │
│                       └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Common Use Cases

### Use Case 1: SSO for Web Applications

1. In authentik, create a new **Provider** (OAuth2/OIDC or SAML)
2. Create an **Application** and link it to the provider
3. Configure your application to use authentik as the IdP

### Use Case 2: LDAP for Legacy Apps

1. Deploy with the LDAP outpost:

```bash
bosh -d authentik deploy manifests/authentik.yml \
  -o operations/add-ldap-outpost.yml \
  -v authentik_ldap_outpost_token=<token-from-ui>
```

2. Configure your legacy app to use LDAP:
   - Host: `<authentik-ip>`
   - Port: `3389` (LDAP) or `6636` (LDAPS)

### Use Case 3: Protect Applications with Proxy

1. Deploy with the proxy outpost
2. Configure authentik to proxy requests to your backend application
3. Users authenticate through authentik before reaching your app

## Scaling for Production

### High Availability

```bash
bosh -d authentik deploy manifests/authentik.yml \
  -o operations/scale-authentik.yml \
  -v authentik_instances=3
```

### Using S3 for Media Storage

```bash
bosh -d authentik deploy manifests/authentik.yml \
  -o operations/use-s3-storage.yml \
  -v s3_region=us-east-1 \
  -v s3_bucket_name=my-authentik-media \
  -v s3_access_key=AKIAXXXXXXXX \
  -v s3_secret_key=xxxxxxxx
```

## Monitoring

Authentik exposes Prometheus metrics on port 9300.

### Add to Prometheus

```yaml
scrape_configs:
  - job_name: 'authentik'
    static_configs:
      - targets: ['<authentik-ip>:9300']
    metrics_path: /metrics
```

### Key Metrics

- `authentik_main_request_duration_seconds` - Request latency
- `authentik_outpost_connection` - Outpost connection status
- `authentik_admin_token` - Token statistics

## Troubleshooting

### Check Deployment Status

```bash
bosh -d authentik instances
bosh -d authentik vms --vitals
```

### View Logs

```bash
# Server logs
bosh -d authentik ssh authentik/0 -c "sudo tail -100 /var/vcap/sys/log/authentik-server/authentik-server.stdout.log"

# Worker logs
bosh -d authentik ssh authentik/0 -c "sudo tail -100 /var/vcap/sys/log/authentik-worker/authentik-worker.stdout.log"

# All BPM logs
bosh -d authentik logs
```

### Check Process Status

```bash
bosh -d authentik ssh authentik/0 -c "sudo /var/vcap/jobs/bpm/bin/bpm list"
```

### Database Connection Issues

```bash
# Test database connectivity
bosh -d authentik ssh authentik/0 -c "source /var/vcap/jobs/authentik-server/config/env.sh && python -c 'import psycopg2; print(\"OK\")'"
```

### Run Migrations Manually

```bash
bosh -d authentik ssh authentik/0
source /var/vcap/jobs/authentik-server/config/env.sh
cd /var/vcap/packages/authentik
python -m manage migrate
```

## Next Steps

- [Configure OAuth2/OIDC providers](https://docs.goauthentik.io/docs/providers/oauth2/)
- [Set up SAML authentication](https://docs.goauthentik.io/docs/providers/saml/)
- [Configure MFA policies](https://docs.goauthentik.io/docs/flow/stages/authenticator_validate/)
- [Integrate with LDAP](https://docs.goauthentik.io/docs/providers/ldap/)
- [Set up user federation](https://docs.goauthentik.io/docs/sources/)

## Getting Help

- [Authentik Documentation](https://docs.goauthentik.io/)
- [Authentik GitHub Issues](https://github.com/goauthentik/authentik/issues)
- [BOSH Documentation](https://bosh.io/docs/)
