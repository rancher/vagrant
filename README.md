# localranchervagrant
![Pretty Picture](https://github.com/chrisurwin/localranchervagrant/blob/master/localranchervagrant.PNG)

Vagrant files to stand up a Local Rancher install with 3 nodes

This runs RancherOS as the base OS for the nodes which doesn't have the guest tools for Virtualbox installed

Start the cluster and the Rancher UI will become accessible on http://172.22.101.100

To see the contents of the registry cache proxy, navigate to http://172.22.101.100:5000/v2/_catalog

The default file will bring up a cattle environment. You can change this by editing `orchestrator` in [the config file](config.yaml).

## Usage

To use this you must have vagrant installed, which can be obtained from www.vagrantup.com

clone the directory and then run **vagrant up**

This has been tested with vagrant 1.9.1 and VirtualBox 5.0.32. If you experience issues with the networking it is likely related to running an older version.

## Config

The config.yml contains any variables that you should need to change, below is a description of the variables and their values:

**orchestrator** - Possible values are `cattle`, `kubernetes`, `mesos` and `swarm` 

This sets the orchestrator that will be used for the environment, as part of the process the Default environment is deleted and we create a new one with the name of the orchestrator. 

**isolated** - Possible values are **true** and **false**

This sets the Rancher Server and Rancher nodes to have no external internet access other than via a proxy server that runs on the master node. This is used to emulate environments where a proxy server is required to access the internet

**sslenabled** - Possible values are **true** and **false**

This uses a pre-generated certificate to terminate the connection to the Rancher server with SSL. This certificate is located in the /certs folder. If this is changed then the public key will need to be replaced in the configure_rancher_node.sh script otherwise the agent will error.

**ssldns** - Default value is **server.rancher.vagrant**

The setting for this needs to match the string that is stored in the SSL certificate that is used for termination.

**version** - Possible values **latest**, **stable**, **v1.x.x** where x.x is any release of Rancher Server
This is the version of Rancher Server that you want to be deployed into you environment

*master* - Settings for the master node that runs the proxy, registry mirror etc, this value should not be changed
*cpus* - Default **1** This is the number of vCPU's that the master node should have
*memory* - Default **1024** This is the amount of RAM to be allocated to the master node, If running on a machine with only 8GB this should be dropped to **512**

*server* - Settings for the server node(s) that runs the Rancher Server, this value should not be changed
*count* - Default **1** This is the number of Rancher Servers to run, if you want to test HA then this should be set to **2** or above
*cpus* - Default **1** This is the number of vCPU's that each server node should have
*memory* - Default **2048** This is the amount of RAM to be allocated to each server node, If running on a machine with only 8GB this should be dropped to **1024**

*node* - Settings for the rancher node(s) that run in the Rancher environment, this value should not be changed
*count* - Default **3** This is the number of nodes to run
*cpus* - Default **1** This is the number of vCPU's that each Rancher node should have
*memory* - Default **2048** This is the amount of RAM to be allocated to each Rancher node, If running on a machine with only 8GB this should be dropped to **1024**

*ip*  - This section defines the IP address ranges for the virtual machines
*master* - Default **172.22.101.100**
*server* - Default **172.22.101.101**
*node* - Default **172.22.101.111**

*linked_clones* - Default value **true** Leave as this as it reduces disk footprint

*net* - Network Settings section, this should not be changed
*private_nic_type* - Default **82545EM** this sometime needs to be changed to **82540EM** This is the network card that is emulated in the virtual machine
*external_ssh* - Default value **false**, Change to true if you want to expose the master node to an external network
*external_port* - Default value **2277**, this is the port that the master node will be exposed on if you enabled *external_ssh*
*network_type* - Default **private_network**
If you wnat to expose the Virtual Machines directly to the network this can be set to **public_network**

*keys* - Subsection fot defining keys to be used when enabling *external_ssh*. The public key will be placed onto all servers, the private key will be placed onto just the master node. You can then use the master node as a jump host to each of the remaining VM's, or access them directly with the ssh key
*public_key* - This should be set to the path of the public key that needs to be uploaded
*private_key* - This should be set to the path of the private key that needs to be uploaded

## Troubleshooting

*VM's not starting but not running any scripts* - Try changing the *private_nic_type*