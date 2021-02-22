#!/bin/sh

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
apt-get install docker-compose 

docker-compose up -d
