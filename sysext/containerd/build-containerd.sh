#!/usr/bin/env bash
set -euxo pipefail

# Configuration
CONTAINERD_VERSION="${CONTAINERD_VERSION:-1.7.24}"
ARCH="${ARCH:-amd64}"
OUTPUT_DIR="${OUTPUT_DIR:-./output}"
SYSEXT_NAME="containerd"

# For gnomeOS compatibility, we need to set the right OS metadata
# or the sysext will need --force to merge
OS_ID="${OS_ID:-_any}"  # Use _any for universal compatibility

mkdir -p "${OUTPUT_DIR}"
WORKDIR=$(mktemp -d)
trap "rm -rf ${WORKDIR}" EXIT
cd "${WORKDIR}"

echo "Downloading containerd version ${CONTAINERD_VERSION} for ${ARCH}"

# Download containerd
curl -fsSL -O "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-static-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
curl -fsSL -O "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-static-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz.sha256sum"
sha256sum --check "containerd-static-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz.sha256sum"
tar -xf "containerd-static-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"

# Get associated runc version
RUNC_VERSION=$(curl -fsSL "https://raw.githubusercontent.com/containerd/containerd/refs/tags/v${CONTAINERD_VERSION}/script/setup/runc-version")
echo "Downloading runc version: ${RUNC_VERSION}"
curl -fsSL -O "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${ARCH}"
curl -fsSL -O "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.sha256sum"
sha256sum --ignore-missing -c runc.sha256sum

# Create sysext directory structure
SYSEXT_ROOT="${WORKDIR}/sysext-root"
mkdir -p "${SYSEXT_ROOT}/usr/bin"
mkdir -p "${SYSEXT_ROOT}/usr/lib/extension-release.d"
mkdir -p "${SYSEXT_ROOT}/usr/lib/systemd/system/multi-user.target.d"

# Copy binaries
cp -a bin/* "${SYSEXT_ROOT}/usr/bin/"
cp -a "runc.${ARCH}" "${SYSEXT_ROOT}/usr/bin/runc"
chmod a+x "${SYSEXT_ROOT}/usr/bin/runc"

# Create extension-release file for OS compatibility
# Using ID=_any makes it compatible with any OS
cat > "${SYSEXT_ROOT}/usr/lib/extension-release.d/extension-release.${SYSEXT_NAME}" <<EOF
ID=${OS_ID}
SYSEXT_LEVEL=1.0
EOF

# Create systemd drop-in to auto-start containerd
cat > "${SYSEXT_ROOT}/usr/lib/systemd/system/multi-user.target.d/10-containerd.conf" <<EOF
[Unit]
Upholds=containerd.service
EOF

# Create containerd.service if not present in base OS
cat > "${SYSEXT_ROOT}/usr/lib/systemd/system/containerd.service" <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

# Build the sysext image (squashfs format)
mksquashfs "${SYSEXT_ROOT}" "${OUTPUT_DIR}/${SYSEXT_NAME}.raw" \
    -all-root -noappend -comp zstd

# Generate checksum
cd "${OUTPUT_DIR}"
sha256sum "${SYSEXT_NAME}.raw" > "SHA256SUMS.${SYSEXT_NAME}"

echo "Created ${OUTPUT_DIR}/${SYSEXT_NAME}.raw"

