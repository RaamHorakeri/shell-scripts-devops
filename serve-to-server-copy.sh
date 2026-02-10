#!/bin/sh

echo "======================================"
echo " Secure Server-to-Server Folder Copy "
echo "======================================"

# Prompt inputs
printf "1. Destination server (user@ip): "
read DEST_SERVER

printf "2. Source server (user@ip): "
read SRC_SERVER

printf "3. Destination path: "
read DEST_PATH

printf "4. Source path: "
read SRC_PATH

printf "5. Access key path: "
read KEY_PATH

echo ""

# Validate inputs
if [ -z "$DEST_SERVER" ] || [ -z "$SRC_SERVER" ] || \
   [ -z "$DEST_PATH" ] || [ -z "$SRC_PATH" ] || \
   [ -z "$KEY_PATH" ]; then
  echo "❌ Error: All fields are mandatory."
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "❌ Error: SSH key not found at $KEY_PATH"
  exit 1
fi

echo "--------------------------------------"
echo " Copy Summary"
echo "--------------------------------------"
echo " Source Server      : $SRC_SERVER"
echo " Source Path        : $SRC_PATH"
echo " Destination Server : $DEST_SERVER"
echo " Destination Path   : $DEST_PATH"
echo " SSH Key            : $KEY_PATH"
echo "--------------------------------------"

printf "Proceed with copy? (yes/no): "
read CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Copy aborted."
  exit 0
fi

echo "🚀 Starting copy..."

scp -i "$KEY_PATH" -r "$SRC_PATH" "$DEST_SERVER:$DEST_PATH"

if [ $? -eq 0 ]; then
  echo "✅ Copy completed successfully."
else
  echo "❌ Copy failed."
fi
