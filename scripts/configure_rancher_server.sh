#!/bin/bash -x

rancher_server_ip="172.22.101.101"
default_password=${2:-password}
node=${3:-3}
rancher_server_version=${4:-stable}
network_type=${5:-false}
sslenabled=${6:-false}
ssldns=${7:-server.rancher.vagrant}
cache_ip=${8:-172.22.101.100}
rancher_env_vars=${9}
registry_prefix="rancher"
curl_prefix="appropriate"

if [ "$network_type" == "airgap" ]; then
   registry_prefix=$cache_ip:5000
   curl_prefix=$cache_ip:5000
fi

if [ "$sslenabled" == 'true' ]; then
  protocol="https"
  rancher_server_ip=$ssldns
else
  protocol="http"
fi

ros config set rancher.docker.insecure_registry "['$cache_ip:5000']"
if [ ! "$network_type" == "airgap" ] ; then
  ros config set rancher.docker.registry_mirror "http://$cache_ip:4000"
  ros config set rancher.system_docker.registry_mirror "http://$cache_ip:4000"
  ros config set rancher.docker.host "['unix:///var/run/docker.sock', 'tcp://0.0.0.0:2375']"
  if [ "$network_type" == "isolated" ]; then
    ros config set rancher.docker.environment "['http_proxy=http://$cache_ip:3128','https_proxy=http://$cache_ip:3128','HTTP_PROXY=http://$cache_ip:3128','HTTPS_PROXY=http://$cache_ip:3128','no_proxy=server.rancher.vagrant,localhost,127.0.0.1','NO_PROXY=server.rancher.vagrant,localhost,127.0.0.1']"
    ros config set rancher.system_docker.environment "['http_proxy=http://$cache_ip:3128','https_proxy=http://$cache_ip:3128','HTTP_PROXY=http://$cache_ip:3128','HTTPS_PROXY=http://$cache_ip:3128','no_proxy=server.rancher.vagrant,localhost,127.0.0.1','NO_PROXY=server.rancher.vagrant,localhost,127.0.0.1']"
  fi
fi
  ros config set rancher.docker.storage_driver overlay
  ros engine switch docker-1.12.6
system-docker restart docker
sleep 5

if [ "$network_type" == "isolated" ] || [ "$network_type" == "airgap" ] ; then
  ros config set rancher.network.dns.nameservers ["'$cache_ip'"]
  system-docker restart network
  route add default gw $cache_ip
fi

if [ "$sslenabled" == 'true' ]; then
  ros config set rancher.network.dns.nameservers ["'$cache_ip'"]
  system-docker restart network
fi

SUSPEND=n
CATTLE_JAVA_OPTS="-Xms128m -Xmx1g -XX:+HeapDumpOnOutOfMemoryError -agentlib:jdwp=transport=dt_socket,server=y,suspend=$SUSPEND,address=1044"

EXTRA_OPTS=""
if [ "$network_type" == "isolated" ]; then
  EXTRA_OPTS="-e http_proxy='http://$cache_ip:3128' \
 -e https_proxy='http://$cache_ip:3128' \
 -e HTTP_PROXY='http://$cache_ip:3128' \
 -e HTTPS_PROXY='http://$cache_ip:3128' \
 -e no_proxy='server.rancher.vagrant,localhost,127.0.0.1' \
 -e NO_PROXY='server.rancher.vagrant,localhost,127.0.0.1'"
fi
rancher_command=""
if [ "$network_type" == "airgap" ]; then
  EXTRA_OPTS="-e CATTLE_BOOTSTRAP_REQUIRED_IMAGE=$cache_ip:5000/rancher/agent:v1.2.5"
  rancher_command="$registry_prefix/rancher/server:$rancher_server_version" 
else
  rancher_command="rancher/server:$rancher_server_version" 
fi

echo Installing Rancher Server
sudo docker run -d --restart=always \
 -p 443:443 \
 -p 80:80 \
 $rancher_env_vars \
 --restart=unless-stopped \
 --name rancher-server \
$rancher_command

# wait until rancher server is ready
while true; do
  wget -T 5 -c https://localhost/ping && break
  sleep 5
done

# Login
LOGINRESPONSE=$(docker run --net=host \
    --rm \
    $curl_prefix/curl \
    -s "https://127.0.0.1/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"admin","password":"admin"}' --insecure)

LOGINTOKEN=$(echo $LOGINRESPONSE | jq -r .token)

# Change password
docker run --net=host \
    --rm \
    $curl_prefix/curl \
     -s "https://127.0.0.1/v3/users?action=changepassword" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"admin","newPassword":"'$default_password'"}' --insecure

# Create API key
APIRESPONSE=$(docker run --net host \
    --rm \
    $curl_prefix/curl \
     -s "https://127.0.0.1/v3/token" -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation","name":""}' --insecure)

# Extract and store token
APITOKEN=$(echo $APIRESPONSE | jq -r .token)

# Configure server-url
SERVERURLRESPONSE=$(docker run --net host \
    --rm \
    $curl_prefix/curl \
     -s 'https://127.0.0.1/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"https://'$rancher_server_ip'"}' --insecure)

# Create cluster
CLUSTERRESPONSE=$(docker run --net host \
    --rm \
    $curl_prefix/curl \
     -s 'https://127.0.0.1/v3/cluster' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" \
     --data-binary '{"type":"cluster","rancherKubernetesEngineConfig":{"ignoreDockerVersion":false,"sshAgentAuth":false,"type":"rancherKubernetesEngineConfig","kubernetesVersion":"v1.8.10-rancher1-1","authentication":{"type":"authnConfig","strategy":"x509"},"network":{"type":"networkConfig","plugin":"flannel","flannelNetworkProvider":{"iface":"eth1"},"calicoNetworkProvider":null},"ingress":{"type":"ingressConfig","provider":"nginx"},"services":{"type":"rkeConfigServices","kubeApi":{"podSecurityPolicy":false,"type":"kubeAPIService"},"etcd":{"type":"etcdService","extraArgs":{"heartbeat-interval":500,"election-timeout":5000}}}},"name":"myfirstcluster"}' --insecure)

# Extract clusterid to use for generating the docker run command
CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`

# Generate cluster registration token
CLUSTERREGTOKEN=$(docker run --net=host \
    --rm \
    $curl_prefix/curl \
     -s 'https://127.0.0.1/v3/clusterregistrationtoken' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure)
