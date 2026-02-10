#!/bin/bash
set -e

SWAPFILE="/swapfile"

# ================================
# GET SWAP SIZE
# ================================
if [ -n "$1" ]; then
    SWAPSIZE="$1"
else
    echo "Enter swap size (example: 2G, 4G, 6G, 8G):"
    read -r SWAPSIZE
fi

if [[ ! "$SWAPSIZE" =~ ^[0-9]+[MG]$ ]]; then
    echo "❌ Invalid swap size format. Use like 2G, 4096M"
    exit 1
fi

echo "======================================"
echo "🚀 Adding swap memory: $SWAPSIZE"
echo "======================================"

# ================================
# CHECK EXISTING SWAP
# ================================
if swapon --show | grep -q "$SWAPFILE"; then
    echo "⚠️ Swapfile already exists and is active."
    swapon --show
    exit 0
fi

# ================================
# CREATE SWAP FILE
# ================================
echo "📁 Creating swap file..."
if command -v fallocate >/dev/null 2>&1; then
    fallocate -l "$SWAPSIZE" "$SWAPFILE"
else
    SIZE_MB=$(echo "$SWAPSIZE" | sed 's/G//;s/M//')
    dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SIZE_MB"
fi

# ================================
# SECURE SWAP FILE
# ================================
echo "🔐 Securing swap file..."
chmod 600 "$SWAPFILE"

# ================================
# FORMAT & ENABLE
# ================================
echo "🧱 Formatting swap..."
mkswap "$SWAPFILE"

echo "⚡ Enabling swap..."
swapon "$SWAPFILE"

# ================================
# PERSIST SWAP
# ================================
if ! grep -q "^$SWAPFILE" /etc/fstab; then
    echo "💾 Persisting swap in /etc/fstab..."
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
fi

# ================================
# TUNING (SERVER SAFE)
# ================================
echo "⚙️ Applying kernel tuning..."

sysctl vm.swappiness=10
sysctl vm.vfs_cache_pressure=50

grep -q "vm.swappiness" /etc/sysctl.conf || echo "vm.swappiness=10" >> /etc/sysctl.conf
grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf || echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

# ================================
# FINAL STATUS
# ================================
echo "======================================"
echo "✅ Swap setup complete"
echo "======================================"
free -h
swapon --show
