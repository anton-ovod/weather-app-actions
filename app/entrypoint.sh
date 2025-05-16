#!/bin/sh

sed -i "s/{{PORT}}/${PORT}/g" /etc/nginx/nginx.conf

echo "========================================="
echo "Aplikacja stworzona przez Anton Ovod."
echo "Uruchomiona dnia $(date) na porcie $PORT"
echo "========================================="

exec nginx -g "daemon off;"
