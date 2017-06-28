#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}
node=${3}
cache_ip=172.22.101.100
rancher_server_version=${4:-stable}
catalog_json=$5

if [ ! "$(ps -ef | grep dockerd | grep -v grep | grep "$cache_ip")" ]; then
  ros config set rancher.docker.registry_mirror "http://$cache_ip:5000"
  ros config set rancher.system_docker.registry_mirror "http://$cache_ip:5000"
  ros config set rancher.docker.host "['unix:///var/run/docker.sock', 'tcp://0.0.0.0:2375']"
  system-docker restart docker
  sleep 5
fi

SUSPEND=n
CATTLE_JAVA_OPTS="-Xms128m -Xmx1g -XX:+HeapDumpOnOutOfMemoryError -agentlib:jdwp=transport=dt_socket,server=y,suspend=$SUSPEND,address=1044"

if [ ! -z "$catalog_json" ]; then
  CATALOG_ENV="-e DEFAULT_CATTLE_CATALOG_URL=$catalog_json"
fi

echo Installing Rancher Server
sudo docker run -d --restart=always \
 -p 8080:8080 \
 -p 8088:8088 \
 -p 1044:1044 \
 -p 9345:9345 \
 -e CATTLE_JAVA_OPTS="$CATTLE_JAVA_OPTS" \
 $CATALOG_ENV \
 --restart=unless-stopped \
 --name rancher-server \
 rancher/server:$rancher_server_version \
 --db-host $cache_ip \
 --db-port 3306 \
 --db-name cattle \
 --db-user root \
 --db-pass cattle \
 --advertise-address `ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

if [ $node -eq 1 ]; then
  # wait until rancher server is ready
  while true; do
    wget -T 5 -c http://$rancher_server_ip && break
    sleep 5
  done

  set -e

  # disable telemetry for developers
 docker run \
    --rm \
    appropriate/curl \
      -s \
      -X POST \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{"type":"setting","name":"telemetry.opt","value":"out"}' \
        "http://$rancher_server_ip/v2-beta/setting"


# lookup orchestrator template id
while true; do
  ENV_TEMPLATE_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    appropriate/curl \
      -s \
        "http://$rancher_server_ip/v2-beta/projectTemplates?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

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
  appropriate/curl \
    -s \
    -X POST \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"description\":\"$orchestrator\",\"name\":\"$orchestrator\",\"projectTemplateId\":\"$ENV_TEMPLATE_ID\",\"allowSystemRole\":false,\"members\":[],\"virtualMachine\":false,\"servicesPortRange\":null}" \
      "http://$rancher_server_ip/v2-beta/projects"

# lookup default environment id
DEFAULT_ENV_ID=$(docker run -v /tmp:/tmp --rm appropriate/curl -s "http://$rancher_server_ip/v2-beta/project?name=Default" | jq '.data[0].id' | tr -d '"')

# delete default environment
docker run \
  --rm \
  appropriate/curl \
    -s \
    -X DELETE \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{}' \
      "http://$rancher_server_ip/v2-beta/projects/$DEFAULT_ENV_ID/?action=delete"
fi
