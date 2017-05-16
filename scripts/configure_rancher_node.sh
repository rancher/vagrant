#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}

if [ "$orchestrator" == "kubernetes" ]; then
  sudo ros engine switch docker-1.12.6
fi

ENV_ID=$(docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -s \
    "http://$rancher_server_ip:8080/v2-beta/project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

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
      "http://$rancher_server_ip:8080/v2-beta/projects/$ENV_ID/registrationtoken"

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -s \
    "http://$rancher_server_ip:8080/v2-beta/projects/$ENV_ID/registrationtokens/?state=active" |
      grep -Eo '[^,]*' |
      grep -E 'command' |
      awk '{gsub("\"command\":\"", ""); gsub("\"", ""); print}' |
      head -n1 |
      sh
