#!/bin/bash

VAR_NAME="$1"
VAR_VALUE="$2"

if [ -z "$VAR_NAME" ]; then
    echo "❌ ENV variable name is required"
    exit 1
fi

ACTION="CREATE"
[ -z "$VAR_VALUE" ] && ACTION="DELETE"

BASHRC="$HOME/.bashrc"
SYSTEM_ENV="/etc/environment"

if [ "$ACTION" = "DELETE" ]; then
    sed -i "/export $VAR_NAME=/d" "$BASHRC"
    [ "$(id -u)" -eq 0 ] && sed -i "/^$VAR_NAME=/d" "$SYSTEM_ENV"
else
    if grep -q "export $VAR_NAME=" "$BASHRC"; then
        sed -i "s|export $VAR_NAME=.*|export $VAR_NAME=\"$VAR_VALUE\"|" "$BASHRC"
    else
        echo "export $VAR_NAME=\"$VAR_VALUE\"" >> "$BASHRC"
    fi

    if [ "$(id -u)" -eq 0 ]; then
        if grep -q "^$VAR_NAME=" "$SYSTEM_ENV"; then
            sed -i "s|^$VAR_NAME=.*|$VAR_NAME=\"$VAR_VALUE\"|" "$SYSTEM_ENV"
        else
            echo "$VAR_NAME=\"$VAR_VALUE\"" >> "$SYSTEM_ENV"
        fi
    fi
fi

echo "✅ $ACTION completed for $VAR_NAME"
