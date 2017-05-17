#!/bin/bash -x

box_type=${1:-node}
rancher_server_ip=${2:-172.22.101.100}
orchestrator=${3:-cattle}

curl() {
  local method=${1-GET} path=${2-schemas} data=$3
  if [ "$data" != "" ]; then
    data="-d \"$data\""
  fi
  docker run \
    --rm \
    appropriate/curl \
      -s \
      -X $method \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      $data \
      "http://$rancher_server_ip:8080/v2-beta/$path"
}

get()    { curl GET    "$1"     ; }
post()   { curl POST   "$1" "$2"; }
put()    { curl PUT    "$1" "$2"; }
delete() { curl DELETE "$1"     ; }

get_template_id() {
  local name=$1 id=null
  while true; do
    id=$(get "projectTemplates?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

    # might've received 422 InvalidReference if the templates haven't populated yet
    if [[ "$id" == 1pt* ]]; then
      echo $id
      break
    else
      sleep 5
    fi
  done
}

server() {
  # wait until rancher server is ready
  while true; do
    wget -T 5 -c http://$rancher_server_ip:8080 && break
    sleep 5
  done

  set -e

  # disable telemetry for developers
  post "setting" '{"type":"setting","name":"telemetry.opt","value":"out"}'

  # lookup orchestrator template id
  ENV_TEMPLATE_ID=$(get_template_id $orchestrator)

  # create an environment with specified orchestrator template
  post "projects" "{\"description\":\"$orchestrator\",\"name\":\"$orchestrator\",\"projectTemplateId\":\"$ENV_TEMPLATE_ID\",\"allowSystemRole\":false,\"members\":[],\"virtualMachine\":false,\"servicesPortRange\":null}"

  # lookup default environment id
  DEFAULT_ENV_ID=$(get "project?name=Default" | jq '.data[0].id' | tr -d '"')

  # delete default environment
  delete "projects/$DEFAULT_ENV_ID/?action=delete" #'{}'
}

node() {
  if [ "$orchestrator" == "kubernetes" ]; then
    sudo ros engine switch docker-1.12.6
  fi

  # get the environment id
  local env_id=$(get "project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

  # create a registration token if one doesn't exist
  if [ "$(get "projects/$env_id/registrationtokens/?state=active" | jq '.data | length')" == "0" ]; then
    echo Creating a registration token
    post "projects/$env_id/registrationtoken" '{"type":"registrationToken"}'
  fi

  # execute the first active registration token
  get "projects/$env_id/registrationtokens/?state=active" |
    grep -Eo '[^,]*' |
    grep -E 'command' |
    awk '{gsub("\"command\":\"", ""); gsub("\"", ""); print}' |
    head -n1 |
    sh
}

eval $box_type
