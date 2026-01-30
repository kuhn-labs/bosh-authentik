#!/bin/bash
set -eu

# Script to download all required blobs for the authentik BOSH release
# Run this script before creating the release

AUTHENTIK_VERSION="${AUTHENTIK_VERSION:-2025.12.1}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12.4}"
SETUPTOOLS_VERSION="${SETUPTOOLS_VERSION:-70.0.0}"
PIP_VERSION="${PIP_VERSION:-24.0}"

BLOB_DIR="$(cd "$(dirname "$0")/.." && pwd)/blobs"

echo "Creating blob directories..."
mkdir -p "${BLOB_DIR}/python"
mkdir -p "${BLOB_DIR}/authentik"
mkdir -p "${BLOB_DIR}/authentik/vendor"
mkdir -p "${BLOB_DIR}/outposts/ldap"
mkdir -p "${BLOB_DIR}/outposts/radius"
mkdir -p "${BLOB_DIR}/outposts/proxy"

echo "Downloading Python ${PYTHON_VERSION}..."
curl -L -o "${BLOB_DIR}/python/Python-${PYTHON_VERSION}.tar.xz" \
  "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"

echo "Downloading setuptools ${SETUPTOOLS_VERSION}..."
curl -L -o "${BLOB_DIR}/python/setuptools-${SETUPTOOLS_VERSION}.tar.gz" \
  "https://files.pythonhosted.org/packages/source/s/setuptools/setuptools-${SETUPTOOLS_VERSION}.tar.gz"

echo "Downloading pip ${PIP_VERSION}..."
curl -L -o "${BLOB_DIR}/python/pip-${PIP_VERSION}.tar.gz" \
  "https://files.pythonhosted.org/packages/source/p/pip/pip-${PIP_VERSION}.tar.gz"

echo ""
echo "=========================================="
echo "MANUAL STEPS REQUIRED:"
echo "=========================================="
echo ""
echo "1. Download authentik source and wheels:"
echo "   - Clone authentik: git clone https://github.com/goauthentik/authentik.git"
echo "   - Create source tarball and place in ${BLOB_DIR}/authentik/"
echo "   - Download Python dependencies as wheels into ${BLOB_DIR}/authentik/vendor/"
echo "   - Create web distribution tarball from the built frontend"
echo ""
echo "   Example commands:"
echo "     cd authentik"
echo "     git checkout ${AUTHENTIK_VERSION}"
echo "     pip download -d ../blobs/authentik/vendor -r requirements.txt"
echo "     tar czf ../blobs/authentik/authentik-${AUTHENTIK_VERSION}.tar.gz ."
echo "     cd web && npm ci && npm run build"
echo "     tar czf ../../blobs/authentik/web-dist.tar.gz dist/"
echo ""
echo "2. Download outpost binaries from GitHub releases:"
echo "   https://github.com/goauthentik/authentik/releases/tag/version%2F${AUTHENTIK_VERSION}"
echo ""
echo "   - Download authentik-ldap_linux_amd64 to ${BLOB_DIR}/outposts/ldap/"
echo "   - Download authentik-radius_linux_amd64 to ${BLOB_DIR}/outposts/radius/"
echo "   - Download authentik-proxy_linux_amd64 to ${BLOB_DIR}/outposts/proxy/"
echo ""
echo "3. Add blobs to the release:"
echo "   bosh add-blob blobs/python/Python-${PYTHON_VERSION}.tar.xz python/Python-${PYTHON_VERSION}.tar.xz"
echo "   bosh add-blob blobs/python/setuptools-${SETUPTOOLS_VERSION}.tar.gz python/setuptools-${SETUPTOOLS_VERSION}.tar.gz"
echo "   bosh add-blob blobs/python/pip-${PIP_VERSION}.tar.gz python/pip-${PIP_VERSION}.tar.gz"
echo "   # ... and all other blobs"
echo ""
echo "4. Create and upload the release:"
echo "   bosh create-release --force"
echo "   bosh upload-release"
echo ""
