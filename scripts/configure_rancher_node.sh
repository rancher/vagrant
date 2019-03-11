#!/bin/bash -x
rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}
network_type=${3:-false}
sslenabled=${4:-false}
ssldns=${5:-server.rancher.vagrant}
cache_ip=${6:-172.22.101.100}


      sed 's/127\.0\.0\.1.*node.*/172\.22\.101\.11#{i} node-0#{i}/' -i /etc/hosts
      apt-get update && apt-get install -y apt-transport-https
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
      echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
      apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
      mkdir -p /etc/apt/sources.list.d
      echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | tee /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y kubelet kubeadm kubectl  
      apt-get -y install docker-engine=1.12.6-0~ubuntu-xenial
      swapoff -a  

      if [ "$HOSTNAME" == "node-01" ]; then
          ssh-keygen -f id_rsa -t rsa -N ''
          sed -i -e 's/root@node-01/vagrant/g' id_rsa.pub
          docker run -d -p 7777:8043 -v /home/vagrant:/srv/http --name goStatic pierrezemb/gostatic
          cat /home/vagrant/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys

      fi
      if [ "$HOSTNAME" != "node-01" ]; then
          curl http://172.22.101.111:7777/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
      fi
      service ssh restart  
