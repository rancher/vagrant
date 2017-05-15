# localranchervagrant
Vagrant files to stand up a Local Rancher install with 3 nodes

This runs RancherOS as the base OS for the nodes which doesn't have the guest tools for Virtualbox installed

Start the server and the Rancher UI will become accessible on http://172.22.101.100:8080

The default file will bring up a cattle environment. You can change this by editing the vagrant file variable $orchestrator, the choices are cattle, kubernetes, swarm and mesos.

## Usage

To use this you must have vagrant installed, which can be obtained from www.vagrantup.com

clone the directory and then run **vagrant up**
