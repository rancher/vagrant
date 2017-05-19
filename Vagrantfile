# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
#
require_relative 'vagrant_rancheros_guest_plugin.rb'

# Proxy Registry Cache
$cache_ip = "172.22.101.100"

#Rancher variables
$orchestrator = "cattle"
$rancher_server_ip = "172.22.101.100"
$rancher_server_version = "latest"
$nic_type = "82545EM"
$rancher_server_node_count = 1

#Node variables
$number_of_nodes = 3
$node_mem = "2048"
$node_cpus = "1"
$vb_gui = false

Vagrant.configure(2) do |config|
  
  # Proxy Registry Cache & NFS
  config.vm.define "cache" do |cache|
    cache.vm.box = "williamyeh/ubuntu-trusty64-docker"
    cache.vm.guest = :ubuntu
    cache.vm.network :private_network, ip: $cache_ip, nic_type: $nic_type
    cache.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--memory", 1024]
      v.customize ["modifyvm", :id, "--name", "cache"]
    end
    cache.vm.provision "shell", path: "scripts/cache.sh"
  end

  # Rancher Server
   (1..$rancher_server_node_count).each do |i|
     hostname = "server-%02d" % i
     config.vm.define hostname do |server|
       server.vm.box= "MatthewHartstonge/RancherOS"
       server.vm.box_url = "MatthewHartstonge/RancherOS"
       server.vm.guest = :linux
       server.vm.provider :virtualbox do |v|
         v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
         v.customize ["modifyvm", :id, "--memory", 2048]
         v.customize ["modifyvm", :id, "--name", hostname]
       end

       ip = "172.22.101.#{i+100}"
       server.vm.network :private_network, ip: ip,nic_type: $nic_type
       server.vm.hostname = hostname
       server.vm.provision "shell", path: "scripts/configure_rancher_server.sh", args: [$rancher_server_ip, $orchestrator, i, $rancher_server_version]
     end
   end

  # Rancher Nodes
  (1..$number_of_nodes).each do |i|
    hostname = "node-%02d" % i
    config.vm.define hostname do |node|
      node.vm.box   = "MatthewHartstonge/RancherOS"
      node.vm.guest = :linux
      node.vm.provider "virtualbox" do |vb|
        vb.memory = $node_mem
        vb.cpus = $node_cpus
        vb.gui = $vb_gui
        vb.customize ["modifyvm", :id, "--name", hostname]
      end

      ip = "172.22.101.#{i+110}"
      node.vm.network "private_network", ip: ip, nic_type: $nic_type
      node.vm.hostname = hostname
      node.vm.provision "shell", path: "scripts/configure_rancher_node.sh", args: [$rancher_server_ip, $orchestrator]
    end
  end

end
