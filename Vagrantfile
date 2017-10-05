# -*- mode: ruby -*-
# vi: set ft=ruby :
require_relative 'vagrant_rancheros_guest_plugin.rb'
require 'ipaddr'
require 'yaml'

x = YAML.load_file('config.yaml')
puts "Config: #{x.inspect}\n\n"

$private_nic_type = x.fetch('net').fetch('private_nic_type')
$external_ssh = x.fetch('external_access').fetch('enabled')

Vagrant.configure(2) do |config|
config.vm.communicator = "ssh"
  config.vm.define "master" do |master|
    c = x.fetch('master')
    master.vm.box = "williamyeh/ubuntu-trusty64-docker"
    master.vm.guest = :ubuntu
    master.vm.network x.fetch('net').fetch('network_type'), ip: x.fetch('ip').fetch('master'), nic_type: $private_nic_type    
    master.vm.provider :virtualbox do |v|
      v.cpus = c.fetch('cpus')
      v.memory = c.fetch('memory')
      v.name = "master"
    end
    if x.fetch('external_access').fetch('enabled')
      master.vm.network "forwarded_port", guest: 22, host: x.fetch('external_access').fetch('ssh_port')
      master.vm.network "forwarded_port", guest: 80, host: x.fetch('external_access').fetch('http_port')
      master.vm.network "forwarded_port", guest: 443, host: x.fetch('external_access').fetch('https_port')
    end
    if x.fetch('sslenabled')
       master.vm.provision "file", source: "./certs/haproxy.crt", destination: "/home/vagrant/haproxy.crt"
    end
    master.vm.provision "shell", path: "scripts/master.sh", args: [x.fetch('network_mode'),x.fetch('sslenabled'),x.fetch('ip').fetch('server'),x.fetch('server').fetch('count'),x.fetch('ip').fetch('master'), x.fetch('version')]
    if File.file?(x.fetch('keys').fetch('private_key'))
       master.vm.provision "file", source: x.fetch('keys').fetch('private_key'), destination: "/home/vagrant/.ssh/id_rsa"
    end
    if File.file?(x.fetch('keys').fetch('public_key')) 
       public_key = File.read(x.fetch('keys').fetch('public_key'))
       master.vm.provision :shell, :inline =>"
         echo 'Copying SSH Keys to the VM'
         mkdir -p /home/vagrant/.ssh
         chmod 700 /home/vagrant/.ssh
         echo '#{public_key}' >> /home/vagrant/.ssh/authorized_keys
         chmod -R 600 /home/vagrant/.ssh/authorized_keys
      ", privileged: false
    end
  end

  server_ip = IPAddr.new(x.fetch('ip').fetch('server'))
  (1..x.fetch('server').fetch('count')).each do |i|
    c = x.fetch('server')
    config.vm.communicator = "ssh"
    hostname = "server-%02d" % i
    config.vm.define hostname do |server|
      server.vm.box= "chrisurwin/RancherOS"
      server.vm.guest = :linux
      server.vm.provider :virtualbox do |v|
        v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        v.cpus = c.fetch('cpus')
        v.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0') and x.fetch('linked_clones')
        v.memory = c.fetch('memory')
        v.name = hostname
      end
      server.vm.network x.fetch('net').fetch('network_type'), ip: IPAddr.new(server_ip.to_i + i - 1, Socket::AF_INET).to_s, nic_type: $private_nic_type
      server.vm.hostname = hostname
      server.vm.provision "shell", path: "scripts/server.sh", args: [x.fetch('ip').fetch('master'), x.fetch('orchestrator'), i, x.fetch('image'), x.fetch('network_mode'), x.fetch('sslenabled'), x.fetch('ssldns'), x.fetch('ip').fetch('master'), x.fetch('rancher_env_vars')]
      if File.file?(x.fetch('keys').fetch('private_key'))
        config.vm.provision "file", source: x.fetch('keys').fetch('private_key'), destination: "/home/rancher/.ssh/id_rsa"
      end
      if File.file?(x.fetch('keys').fetch('public_key')) 
        public_key = File.read(x.fetch('keys').fetch('public_key'))
        server.vm.provision :shell, :inline =>"
          echo 'Copying SSH Keys to the VM'
          mkdir -p /home/rancher/.ssh
          chmod 700 /home/rancher/.ssh
          echo '#{public_key}' >> /home/rancher/.ssh/authorized_keys
          chmod -R 600 /home/rancher/.ssh/authorized_keys
        ", privileged: false
        end
      end
  end

  linux_node_ip = IPAddr.new(x.fetch('ip').fetch('linux_node'))
  (1..x.fetch('linux-node').fetch('count')).each do |i|
    c = x.fetch('linux-node')
    config.vm.communicator = "ssh"
    hostname = "linux-node-%02d" % i
    config.vm.define hostname do |node|
      node.vm.box   = "chrisurwin/RancherOS"
      node.vm.box_version = x.fetch('ROS_version')
      node.vm.guest = :linux
      node.vm.provider "virtualbox" do |v|
        v.cpus = c.fetch('cpus')
        v.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0') and x.fetch('linked_clones')
        v.memory = c.fetch('memory')
        v.name = hostname
      end
      node.vm.network x.fetch('net').fetch('network_type'), ip: IPAddr.new(linux_node_ip.to_i + i - 1, Socket::AF_INET).to_s, nic_type: $private_nic_type
      node.vm.hostname = hostname
      node.vm.provision "shell", path: "scripts/node-linux.sh", args: [x.fetch('ip').fetch('master'), x.fetch('orchestrator'), x.fetch('network_mode'), x.fetch('sslenabled'), x.fetch('ssldns'), x.fetch('ip').fetch('master')]
      if File.file?(x.fetch('keys').fetch('private_key'))
        config.vm.provision "file", source: x.fetch('keys').fetch('private_key'), destination: "/home/rancher/.ssh/id_rsa"
      end
      if File.file?(x.fetch('keys').fetch('public_key')) 
        public_key = File.read(x.fetch('keys').fetch('public_key'))
        node.vm.provision :shell, :inline =>"
          echo 'Copying SSH Keys to the VM'
          mkdir -p /home/rancher/.ssh
          chmod 700 /home/rancher/.ssh
          echo '#{public_key}' >> /home/rancher/.ssh/authorized_keys
          chmod -R 600 /home/rancher/.ssh/authorized_keys
        ", privileged: false
        end
    end
  end

  windows_node_ip = IPAddr.new(x.fetch('ip').fetch('windows_node'))
  (1..x.fetch('windows-node').fetch('count')).each do |i|
    c = x.fetch('windows-node')
    hostname = "windows-node-%02d" % i
    config.vm.define hostname do |node|
      node.vm.network x.fetch('net').fetch('network_type'), ip: IPAddr.new(windows_node_ip.to_i + i - 1, Socket::AF_INET).to_s, nic_type: $private_nic_type
      node.vm.communicator = "winrm"
      node.vm.box   = "jamesoliver/windows2016rancher"
#      node.vm.box_version = "1.0.3"
      node.vm.guest = :windows
      node.vm.provider "virtualbox" do |v|
        v.cpus = c.fetch('cpus')
        v.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0') and x.fetch('linked_clones')
        v.memory = c.fetch('memory')
        v.name = hostname
      end
      # node.vm.hostname = hostname
      node.vm.provision "shell", path: "scripts/node-windows.ps1", args: [IPAddr.new(windows_node_ip.to_i + i - 1, Socket::AF_INET).to_s, x.fetch('ip').fetch('master'), x.fetch('orchestrator'), hostname]
      # node.vm.provision "file", source: "scripts/node-windows.ps1", destination: "c:\\Users\\vagrant\\Documents\\provision.ps1"
      # node.vm.provision "shell", inline: "c:\\Users\\vagrant\\Documents\\provision.ps1 "+ IPAddr.new(windows_node_ip.to_i + i - 1, Socket::AF_INET).to_s + " " + x.fetch('ip').fetch('master') + " " + x.fetch('orchestrator') + " " + hostname
    end
  end  
end
