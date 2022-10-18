#!/bin/bash
#
openssl genrsa -des3 -out server.key 4096
openssl req -new -key server.key -out server.csr
openssl genrsa -des3 -out ca.key 4096
openssl rsa -in server.key -out server.key
openssl req -new -x509 -key ca.key -out ca.crt -days 3650
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt
