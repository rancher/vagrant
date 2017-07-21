#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}
isolated=${3:-false}
cache_ip=172.22.101.100


if [ ! "$(ps -ef | grep dockerd | grep -v grep | grep "$cache_ip")" ]; then
  ros config set rancher.network.dns.nameservers ['172.22.101.100']
  ros config set rancher.docker.registry_mirror "http://$cache_ip:4000"
  ros config set rancher.system_docker.registry_mirror "http://$cache_ip:4000"
  ros config set rancher.docker.host "['unix:///var/run/docker.sock', 'tcp://0.0.0.0:2375']"
  ros config set rancher.docker.insecure_registry "['http://$cache_ip']"
  if [ "$isolated" = 'true' ]; then
    ros config set rancher.docker.environment "['http_proxy=http://172.22.101.100:3128','https_proxy=http://172.22.101.100:3128','HTTP_PROXY=http://172.22.101.100:3128','HTTPS_PROXY=http://172.22.101.100:3128','no_proxy=localhost,127.0.0.1','NO_PROXY=localhost,127.0.0.1']"
  fi
  system-docker restart docker
  sleep 5
fi



#if [ "$orchestrator" == "kubernetes" ] && [ ! "$(ros engine list | grep current | grep docker-1.12.6)" ]; then
  ros engine switch docker-1.12.6
  system-docker restart docker
  sleep 5
#fi

if [ "$isolated" = 'true' ]; then
  route add default gw 172.22.101.100
fi

while true; do
  ENV_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    appropriate/curl \
      -s \
      "http://$rancher_server_ip/v2-beta/project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

  if [[ "$ENV_ID" == 1a* ]]; then
    break
  else
    sleep 5
  fi
done


echo Adding host to Rancher Server

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -s \
    -X POST \
    -H 'Content-Type: application/json' \
    -H 'accept: application/json' \
    -d "{\"type\":\"registrationToken\"}" \
      "http://$rancher_server_ip/v2-beta/projects/$ENV_ID/registrationtoken"

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -s \
    "http://$rancher_server_ip/v2-beta/projects/$ENV_ID/registrationtokens/?state=active" |
      grep -Eo '[^,]*' |
      grep -E 'command' |
      awk '{gsub("\"command\":\"", ""); gsub("\"", ""); print}' |
      head -n1 |
      sh
