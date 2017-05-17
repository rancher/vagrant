#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}

if [ "$orchestrator" == "kubernetes" ]; then
  sudo ros engine switch docker-1.12.6
fi

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

ENV_ID=$(get "project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

# create a registration token if one doesn't exist
if [ "$(get "projects/$ENV_ID/registrationtokens/?state=active" | jq '.data | length')" == "0" ]; then
  echo Creating a registration token
  post "projects/$ENV_ID/registrationtoken" '{"type":"registrationToken"}'
fi

# execute the first active registration token
get "projects/$ENV_ID/registrationtokens/?state=active" |
  grep -Eo '[^,]*' |
  grep -E 'command' |
  awk '{gsub("\"command\":\"", ""); gsub("\"", ""); print}' |
  head -n1 |
  sh
