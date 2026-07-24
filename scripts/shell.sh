#!/bin/bash

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo "Usage:"
    echo "  wp-host shell domain.com"
    exit 1
fi

USER=$(echo "$DOMAIN" | cut -d'.' -f1)

if ! id "$USER" >/dev/null 2>&1; then
    echo "Site not found."
    exit 1
fi

echo ""
echo "Opening shell for $DOMAIN..."
echo ""

sudo -u "$USER" -i
