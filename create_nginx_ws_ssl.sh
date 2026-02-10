#!/bin/bash

# Usage: sudo ./create_nginx_wss_ssl.sh <domain> <port>

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

echo "[INFO] Creating Certbot challenge directory..."
sudo mkdir -p /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot

echo "[INFO] Creating initial ACME validation config..."

sudo bash -c "cat > $NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Allow Certbot validation
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Temporary response until SSL issued
    return 200 "SSL setup in progress...";
}
EOF

echo "[INFO] Testing temporary config..."
sudo nginx -t || { echo "[ERROR] Temporary config failed."; exit 1; }

echo "[INFO] Reloading Nginx..."
sudo systemctl reload nginx

echo "[INFO] Requesting SSL certificate via Certbot..."
sudo certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" \
    -m admin@$DOMAIN --agree-tos --non-interactive || {
    echo "[ERROR] Certbot failed. Check DNS or port 80."
    exit 1
}

echo "[INFO] SSL created — writing final WebSocket-only config..."

sudo bash -c "cat > $NGINX_CONF" <<EOF
# Keep port 80 only for Certbot renewals (no redirect)
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Block HTTP access
    return 403;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL Certificates
    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # WebSocket Proxy (ONLY WSS allowed)
    location / {
        # Reject non-WebSocket normal HTTPS requests
        if (\$http_upgrade != "websocket") {
            return 403;
        }

        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        send_timeout 3600;
    }
}
EOF

echo "[INFO] Validating final config..."
sudo nginx -t || { echo "[ERROR] Final config invalid."; exit 1; }

echo "[INFO] Reloading Nginx..."
sudo systemctl reload nginx

echo ""
echo "🎉 SUCCESS!"
echo "---------------------------------------"
echo " WebSocket URL: wss://$DOMAIN"
echo " Backend Target: ws://127.0.0.1:$PORT"
echo " SSL Certificates: /etc/letsencrypt/live/$DOMAIN/"
echo " HTTP/HTTPS (normal web access): BLOCKED"
echo "---------------------------------------"
echo ""
