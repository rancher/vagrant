# -*- mode: ruby -*-
# vi: set ft=ruby :
require_relative 'vagrant_rancheros_guest_plugin.rb'
require 'ipaddr'
require 'yaml'

x = YAML.load_file('config.yaml')
puts "Config: #{x.inspect}\n\n"

$private_nic_type = x.fetch('net').fetch('private_nic_type')
$external_ssh = x.fetch('net').fetch('external_ssh')

Vagrant.configure(2) do |config|

  config.vm.define "master" do |master|
    c = x.fetch('master')
    master.vm.box = "williamyeh/ubuntu-trusty64-docker"
    master.vm.guest = :ubuntu
    master.vm.network :private_network, ip: x.fetch('ip').fetch('master'), nic_type: $private_nic_type    
    master.vm.provider :virtualbox do |v|
      v.cpus = c.fetch('cpus')
      v.memory = c.fetch('memory')
      v.name = "master"
    end
      master.vm.network "forwarded_port", guest: 22, host: 2277
    master.vm.provision "shell", path: "scripts/master.sh", args: [x.fetch('isolated'),x.fetch('sslenabled')]
  end

  server_ip = IPAddr.new(x.fetch('ip').fetch('server'))
  (1..x.fetch('server').fetch('count')).each do |i|
    c = x.fetch('server')
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
      server.vm.network :private_network, ip: IPAddr.new(server_ip.to_i + i - 1, Socket::AF_INET).to_s, nic_type: $private_nic_type
      server.vm.hostname = hostname
      server.vm.provision "shell", path: "scripts/configure_rancher_server.sh", args: [x.fetch('ip').fetch('master'), x.fetch('orchestrator'), i, x.fetch('version'), x.fetch('isolated'), x.fetch('sslenabled'), x.fetch('ssldns')]
    end
  end

  node_ip = IPAddr.new(x.fetch('ip').fetch('node'))
  (1..x.fetch('node').fetch('count')).each do |i|
    c = x.fetch('node')
    hostname = "node-%02d" % i
    config.vm.define hostname do |node|
      node.vm.box   = "chrisurwin/RancherOS"
      node.vm.guest = :linux
      node.vm.provider "virtualbox" do |v|
        v.cpus = c.fetch('cpus')
        v.linked_clone = true if Gem::Version.new(Vagrant::VERSION) >= Gem::Version.new('1.8.0') and x.fetch('linked_clones')
        v.memory = c.fetch('memory')
        v.name = hostname
      end
      node.vm.network :private_network, ip: IPAddr.new(node_ip.to_i + i - 1, Socket::AF_INET).to_s, nic_type: $private_nic_type
      node.vm.hostname = hostname
      node.vm.provision "shell", path: "scripts/configure_rancher_node.sh", args: [x.fetch('ip').fetch('master'), x.fetch('orchestrator'), x.fetch('isolated'), x.fetch('sslenabled'), x.fetch('ssldns')]
    end
  end

end
