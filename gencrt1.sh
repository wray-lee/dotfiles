#!/bin/bash
set -euo pipefail

# create self-signed server certificate:

read -rp "Enter your domain [www.example.com]: " DOMAIN
DOMAIN=${DOMAIN:-www.example.com}

echo "Create server certificate..."

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$DOMAIN.key" -out "$DOMAIN.crt" \
    -subj "/C=US/ST=Mars/L=iTranswarp/O=iTranswarp/OU=iTranswarp/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN"

cat <<EOF
TODO:
Copy $DOMAIN.crt to /etc/nginx/ssl/$DOMAIN.crt
Copy $DOMAIN.key to /etc/nginx/ssl/$DOMAIN.key
Add configuration in nginx:
server {
    ...
    listen 443 ssl;
    ssl_certificate     /etc/nginx/ssl/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/ssl/$DOMAIN.key;
}
EOF
