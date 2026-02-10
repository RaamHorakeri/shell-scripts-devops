#!/bin/bash

# Usage: sudo ./create_nginx_grpc_ssl.sh <domain> <port>

DOMAIN=$1
PORT=$2

if [[ -z "$DOMAIN" || -z "$PORT" ]]; then
  echo "Usage: $0 <domain> <port>"
  exit 1
fi

NGINX_CONF="/etc/nginx/conf.d/$DOMAIN.conf"

echo "[INFO] Installing Nginx + Certbot..."
sudo apt update -y
sudo apt install -y nginx certbot python3-certbot-nginx

echo "[INFO] Creating Certbot validation directory..."
sudo mkdir -p /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot

echo "[INFO] Creating initial ACME-compatible config (no redirect yet)..."

sudo bash -c "cat > $NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Allow Certbot validation
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Temporary response until SSL enabled
    location / {
        return 200 "Waiting for SSL provisioning...";
    }
}
EOF

echo "[INFO] Testing config..."
sudo nginx -t || { echo "[ERROR] Temporary config failed."; exit 1; }

echo "[INFO] Reloading Nginx..."
sudo systemctl reload nginx

echo "[INFO] Requesting Let's Encrypt certificate..."
sudo certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" \
    -m admin@$DOMAIN --agree-tos --non-interactive || {
    echo "[ERROR] Certbot failed to issue certificate."
    exit 1
}

echo "[INFO] Certificate issued. Applying final gRPC config..."

sudo bash -c "cat > $NGINX_CONF" <<EOF
# HTTP → HTTPS redirect (keeps ACME path for renewals)
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL
    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # gRPC Reverse Proxy
    location / {
        grpc_pass grpc://127.0.0.1:$PORT;

        grpc_set_header Host               \$host;
        grpc_set_header X-Real-IP          \$remote_addr;
        grpc_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto  \$scheme;
        grpc_set_header TE                 "trailers";
    }
}
EOF

echo "[INFO] Validating final configuration..."
sudo nginx -t || { echo "[ERROR] Final config invalid."; exit 1; }

echo "[INFO] Reloading Nginx with SSL..."
sudo systemctl reload nginx

echo ""
echo "🎉 SUCCESS! gRPC Secure Proxy Enabled"
echo "--------------------------------------------"
echo " Domain:      https://$DOMAIN"
echo " gRPC Target: grpc://127.0.0.1:$PORT"
echo " SSL Path:    /etc/letsencrypt/live/$DOMAIN/"
echo "--------------------------------------------"
echo ""
