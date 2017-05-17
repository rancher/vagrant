#!/bin/bash -x

cache_ip=${1:-172.22.101.101}
password=${2:-rancher}

# path to a remote share
share_path=/vagrant/.vagrant/data
mkdir -p $share_path

docker rm -f cadvisor

echo "version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: redis
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
redis:
  addr: redis:6379
  password: $password
  db: 0
  dialtimeout: 10ms
  readtimeout: 10ms
  writetimeout: 10ms
  pool:
    maxidle: 16
    maxactive: 64
    idletimeout: 300s
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
proxy:
  remoteurl: https://registry-1.docker.io" > $share_path/config.yml

mkdir -p $share_path/redis
echo "save 300 1
requirepass \"$password\"" > $share_path/redis/redis.conf

docker run -d --name redis-mirror -p 6379 -v $share_path/redis:/data --entrypoint=/usr/local/bin/redis-server redis /data/redis.conf

docker run -d --restart=always -p 5000:5000 --name v2-mirror \
  -v $share_path:/var/lib/registry --link redis-mirror:redis registry:2 /var/lib/registry/config.yml

# Install nfs server
apt-get update
apt-get install -y nfs-kernel-server
mkdir -p /data
echo "/data *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
service nfs-kernel-server restart
