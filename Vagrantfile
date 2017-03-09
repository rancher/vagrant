# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
#
$registration_token = <<REGISTRATION_TOKEN
curl -XPOST -H 'Content-Type: application/json' -H 'accept: application/json' -d '{"type":"registrationToken"}' 'http://172.22.101.105:8080/v1/projects/1a5/registrationtoken'
REGISTRATION_TOKEN

$install_docker = <<INSTALL_DOCKER
echo Installing docker
#curl -sSL https://get.docker.com | sed 's/apt-get install -y -q docker-engine/apt-get install -y -q docker-engine=1.10.3-0~trusty/g' | sh -
#curl -sSL https://get.docker.com | sh -
curl -sSL --retry 5 --retry-delay 10 https://releases.rancher.com/install-docker/1.12.6.sh| sh
sudo usermod -aG docker ubuntu

INSTALL_DOCKER

$install_rancher_server = <<INSTALL_RANCHER_SERVER
echo Installing Rancher Server
sudo docker run -d --restart=always -p 8080:8080 rancher/server
INSTALL_RANCHER_SERVER

$install_nfs = <<INSTALL_NFS
sudo apt-get -y install nfs-kernel-server rpcbind
sudo mkdir /nfs
sudo echo "/nfs       *(rw,fsid=0,insecure,no_subtree_check,async,no_root_squash)" >> /etc/exports
sudo mkdir /nfs/share
sudo chmod 777 /nfs/share
sudo exportfs -ra
sudo service nfs-kernel-server restart
INSTALL_NFS

Vagrant.configure(2) do |config|

  config.vm.provision "shell", inline: $install_docker
 
  config.vm.define "rancherserver" do |rancherserver|
    rancherserver.vm.hostname = 'rancherserver'
    rancherserver.vm.box= "ubuntu/xenial64"
    rancherserver.vm.box_url = "ubuntu/xenial64"

    rancherserver.vm.network :private_network, ip: "172.22.101.105",
      nic_type: "82545EM"

    rancherserver.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 2048]
      v.customize ["modifyvm", :id, "--name", "rancherserver"]
    end

    rancherserver.vm.provision "shell", inline: $install_rancher_server
    rancherserver.vm.provision "shell", inline: $install_nfs
  end

  config.vm.define "node1" do |node1|
    node1.vm.hostname = 'node1'
    node1.vm.box= "ubuntu/xenial64"
    node1.vm.box_url = "ubuntu/xenial64"

    node1.vm.network :private_network, ip: "172.22.101.101",
      nic_type: "82545EM"

    node1.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 2048]
      v.customize ["modifyvm", :id, "--name", "node1"]
    end

    node1.vm.provision "shell", inline: $registration_token
    node1.vm.provision "shell", path: "script.sh"
  end

 config.vm.define "node2" do |node2|
    node2.vm.hostname = 'node2'
    node2.vm.box= "ubuntu/xenial64"
    node2.vm.box_url = "ubuntu/xenial64"

    node2.vm.network :private_network, ip: "172.22.101.102",
      nic_type: "82545EM"

    node2.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 2048]
      v.customize ["modifyvm", :id, "--name", "node2"]
    end
    node2.vm.provision "shell", path: "script.sh"
  end

 config.vm.define "node3" do |node3|
    node3.vm.hostname = 'node3'
    node3.vm.box= "ubuntu/xenial64"
    node3.vm.box_url = "ubuntu/xenial64"

    node3.vm.network :private_network, ip: "172.22.101.103",
      nic_type: "82545EM"

    node3.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 2048]
      v.customize ["modifyvm", :id, "--name", "node3"]
    end
    node3.vm.provision "shell", path: "script.sh"
  end
end