#!/bin/bash -ex

echo Installing NFS server
sudo ros service enable kernel-headers
sudo ros service up kernel-headers
sudo modprobe nfs
sudo mkdir -p /home/rancher/nfs
sudo docker run -d --name nfs --restart=always --privileged --net=host -v /home/rancher/nfs:/nfsshare -e SHARED_DIRECTORY=/nfsshare itsthenetwork/nfs-server-alpine:4