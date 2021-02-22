#!/bin/sh

apt-get update
apt-get upgrade -y
apt-get install docker-ce docker-compose

mkdir /usr/share/nginx/html
cp ./html /usr/share/nginx/html

docker-compose up -d
