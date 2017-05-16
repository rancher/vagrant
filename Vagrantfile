# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
#
require_relative 'vagrant_rancheros_guest_plugin.rb'

#Rancher variables
$rancher_version = "stable"
$orchestrator = "cattle"
$rancher_server_ip = "172.22.101.100"
$nic_type = "82545EM"

#Node variables
$number_of_nodes = 3
$vm_mem = "2048"
$vb_gui = false

Vagrant.configure(2) do |config|

  config.vm.define "rancherserver" do |rancherserver|
  config.vm.guest = :linux
   rancherserver.vm.box= "MatthewHartstonge/RancherOS"
    rancherserver.vm.box_url = "MatthewHartstonge/RancherOS"
    rancherserver.vm.hostname = 'rancherserver'

    rancherserver.vm.network :private_network, ip: "172.22.101.100",
      nic_type: $nic_type

    rancherserver.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory", 2048]
      v.customize ["modifyvm", :id, "--name", "rancherserver"]
    end

    rancherserver.vm.provision "shell", path: "scripts/install_rancher_server.sh", args: $rancher_version
    rancherserver.vm.provision "shell", path: "scripts/install_nfs.sh"
    rancherserver.vm.provision "shell", path: "scripts/configure_rancher_server.sh", args: [$rancher_server_ip, $orchestrator]
   end
end

Vagrant.configure(2) do |config|
  config.vm.box   = "MatthewHartstonge/RancherOS"

  (1..$number_of_nodes).each do |i|
    hostname = "node-%02d" % i
    config.vm.guest = :linux
    config.vm.define hostname do |node|
        node.vm.provider "virtualbox" do |vb|
            vb.memory = $vm_mem
            vb.gui = $vb_gui
            vb.customize ["modifyvm", :id, "--name", hostname]
        end

        ip = "172.22.101.#{i+100}"
        node.vm.network "private_network", ip: ip, nic_type: $nic_type
        node.vm.hostname = hostname
        node.vm.provision "shell", path: "scripts/configure_rancher_node.sh", args: [$rancher_server_ip, $orchestrator]
    end
  end
end
