#!/bin/bash
set -euo pipefail

read -rp "Domain: " DOMAIN

# CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.crt

# Server
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -days 825 -sha256 -out server.crt \
    -extfile <(printf 'subjectAltName=DNS:%s\n' "$DOMAIN")

echo "生成完成: ca.crt ca.key server.crt server.key"
