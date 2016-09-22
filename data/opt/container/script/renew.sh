#!/bin/bash

# Renews Let's Encrypt certificates.
# Adapted from https://letsecure.me/secure-web-deployment-with-lets-encrypt-and-nginx/

if [ ! certbot renew --webroot --webroot-path /var/www/letsencrypt-well-known > /var/log/letsencrypt/renew.log 2>&1 ]
then
     echo "[error] Let's Encrypt automated certificate renewal failed:"
     cat /var/log/letsencrypt/renew.log

     exit 1
fi

/usr/share/nginx/sbin/nginx -s reload
