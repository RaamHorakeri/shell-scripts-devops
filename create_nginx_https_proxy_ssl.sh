#!/bin/bash
set -e

# Usage:
# sudo ./deploy_domain_proxy_ssl_ubuntu.sh your.domain.com 1500

DOMAIN="$1"
PORT="$2"

if [[ -z "$DOMAIN" || -z "$PORT" ]]; then
  echo "❌ Usage: $0 <domain> <port>"
  exit 1
fi

echo "=============================================="
echo "🚀 Deploying Secure HTTPS Reverse Proxy (Ubuntu)"
echo "Domain : $DOMAIN"
echo "Port   : $PORT"
echo "NGINX  : /etc/nginx/conf.d"
echo "=============================================="

echo "[INFO] Updating package index..."
apt update -y

echo "[INFO] Installing NGINX..."
apt install -y nginx

echo "[INFO] Enabling & starting NGINX..."
systemctl enable nginx
systemctl start nginx

NGINX_CONF="/etc/nginx/conf.d/${DOMAIN}.conf"

echo "[INFO] Creating NGINX reverse proxy config → $NGINX_CONF"

cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log  /var/log/nginx/${DOMAIN}_error.log;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        proxy_request_buffering off;
    }
}
EOF

echo "[INFO] Testing NGINX configuration..."
nginx -t

echo "[INFO] Reloading NGINX..."
systemctl reload nginx

echo "[INFO] Configuring firewall (UFW)..."
ufw allow 80 >/dev/null 2>&1 || true
ufw allow 443 >/dev/null 2>&1 || true
ufw reload >/dev/null 2>&1 || true

echo "[INFO] Installing Certbot..."
apt install -y certbot python3-certbot-nginx

echo "[INFO] Requesting SSL certificate from Let's Encrypt..."
certbot --nginx \
  -d "$DOMAIN" \
  --email "admin@$DOMAIN" \
  --agree-tos \
  --redirect \
  --non-interactive

echo ""
echo "=============================================="
echo "🎉 SUCCESS! Deployment Complete"
echo "----------------------------------------------"
echo "🔗 HTTP  → http://$DOMAIN"
echo "🔐 HTTPS → https://$DOMAIN"
echo "----------------------------------------------"
echo "Reverse Proxy → http://127.0.0.1:$PORT"
echo "NGINX Config  → $NGINX_CONF"
echo "SSL Auto-Renew Enabled"
echo "=============================================="
