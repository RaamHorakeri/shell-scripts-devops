#!/bin/sh

# Usage:
#   ./create-ssh-key.sh <ssh_key_name>
#
# Example:
#   ./create-ssh-key.sh my-new-key

# Check for argument
if [ -z "$1" ]; then
  echo "Usage: $0 <ssh_key_name>"
  exit 1
fi

KEY_NAME=$1
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"

# Make sure .ssh exists
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Detect OS
OS_TYPE=$(uname | tr '[:upper:]' '[:lower:]')

echo "Detected OS: $OS_TYPE"

# Common ssh-keygen command
if command -v ssh-keygen >/dev/null 2>&1; then
  if [ "$OS_TYPE" = "linux" ] || echo "$OS_TYPE" | grep -qi "ubuntu"; then
    echo "Running on Ubuntu/Linux"
  elif echo "$OS_TYPE" | grep -qi "mingw"; then
    echo "Running on Windows (Git Bash)"
  elif echo "$OS_TYPE" | grep -qi "msys"; then
    echo "Running on Windows (MSYS)"
  elif echo "$OS_TYPE" | grep -qi "nt"; then
    echo "Running on Windows (WSL)"
  else
    echo "Unknown or unsupported OS: $OS_TYPE"
  fi

  echo "Generating SSH key at $KEY_PATH"

  ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -q

  echo "SSH key generated:"
  echo "Private: $KEY_PATH"
  echo "Public:  ${KEY_PATH}.pub"
else
  echo "ssh-keygen not found. Please install OpenSSH."
  exit 1
fi
