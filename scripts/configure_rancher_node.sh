#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}
isolated=${3:-false}
sslenabled=${4:-false}
ssldns=${5:-server.rancher.vagrant}
cache_ip=${6:-172.22.101.100}
if [ "$sslenabled" == 'true' ]; then
  protocol="https"
  rancher_server_ip=$ssldns
else
  protocol="http"
fi

if [ ! "$(ps -ef | grep dockerd | grep -v grep | grep "$cache_ip")" ]; then
  ros config set rancher.docker.registry_mirror "http://$cache_ip:4000"
  ros config set rancher.system_docker.registry_mirror "http://$cache_ip:4000"
  ros config set rancher.docker.host "['unix:///var/run/docker.sock', 'tcp://0.0.0.0:2375']"
  ros config set rancher.docker.insecure_registry "['$cache_ip:5000']"
  if [ "$isolated" == 'true' ]; then
    ros config set rancher.docker.environment "['http_proxy=http://$cache_ip:3128','https_proxy=http://$cache_ip:3128','HTTP_PROXY=http://$cache_ip:3128','HTTPS_PROXY=http://$cache_ip:3128','no_proxy=server.rancher.vagrant,localhost,127.0.0.1','NO_PROXY=server.rancher.vagrant,localhost,127.0.0.1']"
    ros config set rancher.system_docker.environment "['http_proxy=http://$cache_ip:3128','https_proxy=http://$cache_ip:3128','HTTP_PROXY=http://$cache_ip:3128','HTTPS_PROXY=http://$cache_ip:3128','no_proxy=server.rancher.vagrant,localhost,127.0.0.1','NO_PROXY=server.rancher.vagrant,localhost,127.0.0.1']"
  fi
  system-docker restart docker
  sleep 5
fi

if [ "$sslenabled" == 'true' ]; then
mkdir -p /var/lib/rancher/etc/ssl
echo "-----BEGIN CERTIFICATE-----
MIIDFTCCAf2gAwIBAgIJAN2yyLTWbidBMA0GCSqGSIb3DQEBBQUAMCExHzAdBgNV
BAMMFnNlcnZlci5yYW5jaGVyLnZhZ3JhbnQwHhcNMTcwNzI5MTQxMjQ1WhcNMjcw
NzI3MTQxMjQ1WjAhMR8wHQYDVQQDDBZzZXJ2ZXIucmFuY2hlci52YWdyYW50MIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwLq7oWQwnSAR696FL7w2W7t/
MVCioPnnJV8tFfTvIZ/zQsH4ul9rjdv0NGLcPEXXtdDxsadn+hMWUYAqPNn2YDav
pa0HhEFL/WGnUAP/XE2Vrop7QYh/heu8BIOOQ2rAOaxlLUscDYSmA3BeIEIoDLSc
+A9+xVMikc6SkSQ4qpZOF7GvLfbwEYs3ii7PFUTzxDbmWsOuEEyRyJ36+6fmTTIu
w6rrnsCqUF7AfIEcgxEVOTxtMoY/v8427AP+0B4pAGrY7siwqoiXtWERraVuyAwn
0IkKK4LH/lH30KwzPZTV825aE2Ob05MAg3Sbgi83BfMZQpbloJKj/MosmcXfGwID
AQABo1AwTjAdBgNVHQ4EFgQUXlHYBOn21xjD64UiFrQa+hoFFyIwHwYDVR0jBBgw
FoAUXlHYBOn21xjD64UiFrQa+hoFFyIwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0B
AQUFAAOCAQEAQo+VJv2VkXAe03RL5PBSopE50XNF0xUvMH45gt2lnh4bz2HXTaLy
XcbMzFWeClKWvkqfb9vhlClhmusJYYzkWsSJ5il7YNYVI4m+z33XtTeR0Pzuy2XQ
BrRf+kz6KP5DJt1HusTN+gJFJ0EI850USscCjR2TiPWe7zgKt8WJ/W5c3rVwLFy5
Z/nsoi16UmSJXKkJzXA+tM6K5DCx1p4LmuZXSzB5EwkL9okqA903Vj6kv9JwaHJl
4IgQPgzN0f5iPZNsMboEFfhcYVRRYoznnJzL7VCg1ig5j9JyfsjSpozVFE2CY/52
tRubyXjH+dQQftBUuzwULwwKGL0le7o/vA==
-----END CERTIFICATE-----" > /var/lib/rancher/etc/ssl/ca.crt
fi


if [ "$orchestrator" == "kubernetes" ] && [ ! "$(ros engine list | grep current | grep docker-1.12.6)" ]; then
  ros engine switch docker-1.12.6
  system-docker restart docker
  sleep 5
fi

if [ "$isolated" == 'true' ]; then
  ros config set rancher.network.dns.nameservers ["'$cache_ip'"]
  system-docker restart network
  route add default gw $cache_ip
fi

if [ "$sslenabled" == 'true' ]; then
  ros config set rancher.network.dns.nameservers ["'$cache_ip'"]
  system-docker restart network
fi

while true; do
  ENV_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    appropriate/curl \
      -sLk \
      "$protocol://$rancher_server_ip/v2-beta/project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

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
    -sLk \
    -X POST \
    -H 'Content-Type: application/json' \
    -H 'accept: application/json' \
    -d "{\"type\":\"registrationToken\"}" \
      "$protocol://$rancher_server_ip/v2-beta/projects/$ENV_ID/registrationtoken"

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -sLk \
    "$protocol://$rancher_server_ip/v2-beta/projects/$ENV_ID/registrationtokens/?state=active" |
      grep -Eo '[^,]*' |
      grep -E 'command' |
      awk '{gsub("\"command\":\"", ""); gsub("\"", ""); print}' |
      head -n1 |
      sh
