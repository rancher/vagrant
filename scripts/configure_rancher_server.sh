#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}
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
 -p 8080:8080 \
 -p 8088:8088 \
 -p 1044:1044 \
 -p 9345:9345 \
 $EXTRA_OPTS \
 -e CATTLE_JAVA_OPTS="$CATTLE_JAVA_OPTS" \
 $rancher_env_vars \
 --restart=unless-stopped \
 --name rancher-server \
 $rancher_command \
 --db-host $cache_ip \
 --db-port 3306 \
 --db-name cattle \
 --db-user root \
 --db-pass cattle \
 --advertise-address `ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

if [ $node -eq 1 ]; then
  # wait until rancher server is ready
  while true; do
    wget -T 5 -c $protocol://$rancher_server_ip && break
    sleep 5
  done

  set -e

  # disable telemetry for developers
 docker run \
    --rm \
    $curl_prefix/curl \
      -sLk \
      -X POST \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{"type":"setting","name":"telemetry.opt","value":"out"}' \
        "$protocol://$rancher_server_ip/v2-beta/setting"

 # set default registry for Rancher images
 if [ "$network_type" == "airgap" ] ; then
 docker run \
    --rm \
    $curl_prefix/curl \
      -sLk \
      -X POST \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{"type":"setting","name":"registry.default","value":"'$cache_ip':5000"}' \
        "$protocol://$rancher_server_ip/v2-beta/setting"

fi

# lookup orchestrator template id
while true; do
  ENV_TEMPLATE_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    $curl_prefix/curl \
      -sLk \
        "$protocol://$rancher_server_ip/v2-beta/projectTemplates?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

  # might've received 422 InvalidReference if the templates haven't populated yet
  if [[ "$ENV_TEMPLATE_ID" == 1pt* ]]; then
    break
  else
    sleep 5
  fi
done

# create an environment with specified orchestrator template
docker run \
  -v /tmp:/tmp \
  --rm \
  $curl_prefix/curl \
    -sLk \
    -X POST \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"description\":\"$orchestrator\",\"name\":\"$orchestrator\",\"projectTemplateId\":\"$ENV_TEMPLATE_ID\",\"allowSystemRole\":false,\"members\":[],\"virtualMachine\":false,\"servicesPortRange\":null}" \
      "$protocol://$rancher_server_ip/v2-beta/projects"

# lookup default environment id
DEFAULT_ENV_ID=$(docker run -v /tmp:/tmp --rm $curl_prefix/curl -sLk "$protocol://$rancher_server_ip/v2-beta/project?name=Default" | jq '.data[0].id' | tr -d '"')

# delete default environment
docker run \
  --rm \
  $curl_prefix/curl \
    -sLk \
    -X DELETE \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{}' \
      "$protocol://$rancher_server_ip/v2-beta/projects/$DEFAULT_ENV_ID/?action=delete"
fi

# lookup default environment id
ORCH_ENV_ID=$(docker run -v /tmp:/tmp --rm $curl_prefix/curl -sLk "$protocol://$rancher_server_ip/v2-beta/project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

docker run \
  -v /tmp:/tmp \
  --rm \
  $curl_prefix/curl \
    -sLk \
    -X POST \
    -H 'Content-Type: application/json' \
    -H 'accept: application/json' \
    -d "{\"type\":\"registrationToken\"}" \
      "$protocol://$rancher_server_ip/v2-beta/projects/$ORCH_ENV_ID/registrationtoken"