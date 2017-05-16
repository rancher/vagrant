# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
#
require_relative 'vagrant_rancheros_guest_plugin.rb'

#Rancher variables
$orchestrator = "cattle"
$rancher_server_ip = "172.22.101.100"
$nic_type = "82545EM"

#Node variables
$number_of_nodes = 3
$vm_mem = "2048"
$vb_gui = false

$install_rancher_server = <<INSTALL_RANCHER_SERVER
echo Installing Rancher Server
sudo docker run -d --restart=always -p 8080:8080 rancher/server
sudo mkdir /nfs
sudo docker run -d --name nfs --privileged cpuguy83/nfs-server /nfs
INSTALL_RANCHER_SERVER

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

    rancherserver.vm.provision "shell", inline: $install_rancher_server
    rancherserver.vm.provision "shell", inline: "sleep 180"
    rancherserver.vm.provision "shell", inline: "echo \"while true;do\" > /tmp/script.sh"
    rancherserver.vm.provision "shell", inline: "echo \"wget -T 5 -c http://" + $rancher_server_ip + ":8080 && break\" >> /tmp/script.sh"
    rancherserver.vm.provision "shell", inline: "echo \"sleep 5\" >> /tmp/script.sh"
    rancherserver.vm.provision "shell", inline: "echo \"done\" >> /tmp/script.sh"

    rancherserver.vm.provision "shell", inline: "echo \"TEMPLATEID=\\\$(docker run -v /tmp:/tmp --rm appropriate/curl 'http://" + $rancher_server_ip + ":8080/v2-beta/projectTemplates?name=" + $orchestrator + "' | jq '.data[0].id' | tr -d '\\\"')\" >> /tmp/script.sh"
    rancherserver.vm.provision "shell", inline: "echo \"docker run -v /tmp:/tmp --rm appropriate/curl  -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{\\\"description\\\":\\\"" + $orchestrator + "\\\", \\\"name\\\":\\\"" + $orchestrator + "\\\", \\\"projectTemplateId\\\":\\\"'\\\"\\\$TEMPLATEID\\\"'\\\", \\\"allowSystemRole\\\":false, \\\"members\\\":[], \\\"virtualMachine\\\":false, \\\"servicesPortRange\\\":null}' http://" + $rancher_server_ip + ":8080/v2-beta/projects;\" >> /tmp/script.sh"
    #rancherserver.vm.provision "shell", inline: "echo \"ENVID=\\\$(docker run -v /tmp:/tmp --rm appropriate/curl 'http://" + $rancher_server_ip + ":8080/v2-beta/project?name=" + $orchestrator + "' | jq '.data[0].id' | tr -d '\\\"')\" >> /tmp/script.sh"
    rancherserver.vm.provision "shell", inline: "echo \"DEFAULTID=\\\$(docker run -v /tmp:/tmp --rm appropriate/curl 'http://" + $rancher_server_ip + ":8080/v2-beta/project?name=Default' | jq '.data[0].id' | tr -d '\\\"')\" >> /tmp/script.sh"
    rancherserver.vm.provision "shell", inline: "echo \"docker run --rm appropriate/curl -X DELETE -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{}' 'http://" + $rancher_server_ip + ":8080/v2-beta/projects/'\\\$DEFAULTID'/?action=delete'\" >> /tmp/script.sh"

    rancherserver.vm.provision "shell", inline: "chmod +x /tmp/script.sh"
    rancherserver.vm.provision "shell", inline: "/tmp/script.sh"

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
        if $orchestrator == "kubernetes"
          node.vm.provision "shell", inline: "sudo ros engine switch docker-1.12.6"
        end

        node.vm.provision "shell", inline: "echo \"ENVID=\\\$(docker run -v /tmp:/tmp --rm appropriate/curl 'http://" + $rancher_server_ip + ":8080/v2-beta/project?name=" + $orchestrator + "' | jq '.data[0].id' | tr -d '\\\"')\" >> /tmp/script.sh"
        node.vm.provision "shell", inline: "echo \"echo \"Adding host to Rancher Server\"\" >> /tmp/script.sh"
        node.vm.provision "shell", inline: "echo \"echo \"Processing command...\\\$ENVID\"\" >> /tmp/script.sh"
        node.vm.provision "shell", inline: "echo \"docker run -v /tmp:/tmp --rm appropriate/curl -XPOST -H 'Content-Type: application/json' -H 'accept: application/json' -d '{\\\"type\\\":\\\"registrationToken\\\"}' 'http://" + $rancher_server_ip + ":8080/v2-beta/projects/'\\\$ENVID'/registrationtoken'\" >> /tmp/script.sh"
        node.vm.provision "shell", inline: "echo \"docker run -v /tmp:/tmp --rm appropriate/curl http://" + $rancher_server_ip + ":8080/v2-beta/projects/\\\$ENVID/registrationtokens/ | grep -Eo '[^,]*' | grep -E 'command' | awk '{gsub\(\\\"command\\\\\\\":\\\", \\\"\\\"); gsub\(\\\"\\\\\\\"\\\", \\\"\\\");print}' > /tmp/install.sh\" >> /tmp/script.sh"
        
        
        node.vm.provision "shell", inline: "echo \"chmod +x /tmp/install.sh\" >> /tmp/script.sh"
        node.vm.provision "shell", inline: "echo \"/tmp/install.sh\" >> /tmp/script.sh"
        node.vm.provision "shell", inline: "chmod +x /tmp/script.sh"
        node.vm.provision "shell", inline: "/tmp/script.sh"
    end
  end
end
