#!/bin/sh

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

mkdir /usr/share/nginx
mkdir /usr/share/nginx/html
cp ./html /usr/share/nginx/html

docker-compose up -d
