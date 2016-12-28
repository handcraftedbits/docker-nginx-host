#!/bin/bash

# Renews Let's Encrypt certificates.
# Adapted from https://letsecure.me/secure-web-deployment-with-lets-encrypt-and-nginx/

logFile=/var/log/letsencrypt/renew.log

date >> ${logFile}
echo -e "---\n" >> ${logFile}
certbot renew --webroot --webroot-path /var/www/letsencrypt-well-known >> ${logFile} 2>&1
echo -e "\n" >> ${logFile}

/usr/share/nginx/sbin/nginx -s reload
