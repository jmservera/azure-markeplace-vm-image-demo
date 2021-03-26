#!/bin/sh

echo Installing docker and compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

sudo apt-get install -y docker-compose 

echo Run compose and start the web server
sudo docker-compose up -d
