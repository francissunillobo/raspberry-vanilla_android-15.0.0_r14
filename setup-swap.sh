#!/usr/bin/env bash
set -e

echo "Disabling existing swapfile (if any)..."
sudo swapoff /swapfile || true

echo "Removing old /swapfile (if any)..."
sudo rm -f /swapfile || true

echo "Creating 32G swapfile at /swapfile..."
sudo fallocate -l 32G /swapfile   # change to 16G if you prefer
sudo chmod 600 /swapfile

echo "Setting up swap area..."
sudo mkswap /swapfile

echo "Enabling swapfile..."
sudo swapon /swapfile

echo "Ensuring /swapfile is in /etc/fstab..."
if ! grep -q "^/swapfile " /etc/fstab; then
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo "Current swap configuration:"
swapon --show

echo "Current memory summary:"
free -h

