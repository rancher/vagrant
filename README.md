# localranchervagrant
Vagrant files to stand up a Local Rancher install with 3 nodes

This runs RancherOS as the base OS for the nodes which doesn't have the guest tools for Virtualbox installed

Start the server and the Rancher UI will become accessible on http://172.22.101.100:8080

Starting the nodes will automatically add three nodes to the default cattle environment

The default engine is set to 1.12.6 so that Kubernetes can be run, this can be changed by editing the Vagrantfile
