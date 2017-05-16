#!/bin/bash -ex

echo Installing NFS server
sudo mkdir /nfs
sudo docker run -d --name nfs --privileged cpuguy83/nfs-server /nfs
