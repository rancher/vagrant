#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}
rancher_server_version=${3:-stable}
cache_ip=172.22.101.101

if [ ! "$(ps -ef | grep dockerd | grep -v grep | grep "$cache_ip")" ]; then
  ros config set rancher.docker.registry_mirror "http://$cache_ip:5000"
  ros config set rancher.system_docker.registry_mirror "http://$cache_ip:5000"
  system-docker restart docker
  sleep 5
fi

echo Install MySQL
docker run \
  -d \
  --name mysql \
  -p 3306:3306 \
  -v mysql:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=cattle \
  mysql:5.7.18

if [ $? -eq 0 ]; then
  sleep 15
  echo Creating database
  docker exec -i mysql \
    mysql \
      --password=cattle \
      -e "CREATE DATABASE IF NOT EXISTS cattle COLLATE = 'utf8_general_ci' CHARACTER SET = 'utf8';"
fi

SUSPEND=n
CATTLE_JAVA_OPTS="-Xms128m -Xmx1g -XX:+HeapDumpOnOutOfMemoryError -agentlib:jdwp=transport=dt_socket,server=y,suspend=$SUSPEND,address=1044"

echo Installing Rancher Server
sudo docker run \
  -d \
  --restart=always \
  -p 8080:8080 \
  -p 8088:8088 \
  -p 1044:1044 \
  -e CATTLE_DB_CATTLE_MYSQL_HOST=mysql \
  -e CATTLE_DB_CATTLE_MYSQL_PORT=3306 \
  -e CATTLE_DB_CATTLE_MYSQL_NAME=cattle \
  -e CATTLE_DB_CATTLE_USERNAME=root \
  -e CATTLE_DB_CATTLE_PASSWORD=cattle \
  -e CATTLE_JAVA_OPTS="$CATTLE_JAVA_OPTS" \
  --link mysql:mysql \
  --restart=unless-stopped \
  --name rancher-server \
    rancher/server:$rancher_server_version

# wait until rancher server is ready
while true; do
  wget -T 5 -c http://$rancher_server_ip:8080 && break
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
      "http://$rancher_server_ip:8080/v2-beta/setting"


# lookup orchestrator template id
while true; do
  ENV_TEMPLATE_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    appropriate/curl \
      -s \
        "http://$rancher_server_ip:8080/v2-beta/projectTemplates?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

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
      "http://$rancher_server_ip:8080/v2-beta/projects"

# lookup default environment id
DEFAULT_ENV_ID=$(docker run -v /tmp:/tmp --rm appropriate/curl -s "http://$rancher_server_ip:8080/v2-beta/project?name=Default" | jq '.data[0].id' | tr -d '"')

# delete default environment
docker run \
  --rm \
  appropriate/curl \
    -s \
    -X DELETE \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{}' \
      "http://$rancher_server_ip:8080/v2-beta/projects/$DEFAULT_ENV_ID/?action=delete"
