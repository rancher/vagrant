#!/bin/bash -ex

version=${1:-stable}

echo Installing Rancher Server
sudo docker run -d --restart=always -p 8080:8080 rancher/server:$version
