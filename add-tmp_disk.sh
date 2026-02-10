#!/bin/bash

echo "📌 Backing up /etc/fstab..."
cp /etc/fstab /etc/fstab.bak

echo "📌 Checking if /tmp config already exists..."
if grep -q "^tmpfs /tmp" /etc/fstab; then
    echo "ℹ️ Existing /tmp tmpfs entry found. Opening for edit in vi..."
else
    echo "➕ Adding /tmp tmpfs entry..."
    echo -e "\ntmpfs /tmp tmpfs size=2G 0 0" >> /etc/fstab
fi

echo "📌 Opening /etc/fstab in vi — review and save (:wq)..."
sleep 2
vi /etc/fstab

echo "📌 Remounting /tmp with new size..."
mount -o remount /tmp

echo "📌 Updated /tmp size:"
df -h /tmp

echo "✅ Done!"

