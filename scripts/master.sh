#!/bin/bash -x
network_mode=${1:-false}
sslenabled=${2:-false}
rancher_server_ip=${3:-172.22.101.101}
rancher_server_node=${4:-1}
cache_ip=${5:-172.22.101.100}
rancher_server_version=${6:-latest}
password=${7:-rancher}


apt-get update
apt-get install jq
apt-get install docker-engine


echo "DOCKER_OPTS=\"\$DOCKER_OPTS --registry-mirror http://$cache_ip:4000 --insecure-registry http://$cache_ip:5000 --insecure-registry http://$cache_ip:4000\"" >> /etc/default/docker
service docker restart

# path to a remote share
share_path=/vagrant/.vagrant/data
mkdir -p $share_path

# base configuration path
config_path=/etc/vagrant/
mkdir -p $config_path

chmod 0700 /home/vagrant/.ssh/rancher_id
chown vagrant /home/vagrant/.ssh/rancher_id

docker rm -f cadvisor

echo "version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: redis
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
redis:
  addr: redis:6379
  password: $password
  db: 0
  dialtimeout: 10ms
  readtimeout: 10ms
  writetimeout: 10ms
  pool:
    maxidle: 16
    maxactive: 64
    idletimeout: 300s
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
proxy:
  remoteurl: https://registry-1.docker.io" > $config_path/config.yml

mkdir -p $share_path/redis
echo "save 300 1
requirepass \"$password\"" > $share_path/redis/redis.conf

redis_image=redis_image.tar
if [ -f $share_path/$redis_image ]; then
  docker load -i $share_path/$redis_image
fi

docker run -d --restart=always --name redis-mirror -p 6379 -v $share_path/redis:/data --entrypoint=/usr/local/bin/redis-server redis /data/redis.conf

if [ ! -f $share_path/$redis_image ] ; then
  docker save -o $share_path/$redis_image redis
fi

registry_image=registry_v2_image.tar
if [ -f $share_path/$registry_image ]; then
  docker load -i $share_path/$registry_image
fi

docker run -d --restart=always -p 4000:5000 --name v2-mirror \
  -v $share_path:/var/lib/registry --link redis-mirror:redis registry:2 /var/lib/registry/config.yml

if [ ! -f $share_path/$registry_image ] ; then
  docker save -o $share_path/$registry_image registry:2
fi

# Allow for --provison to clean the cattle DB
docker stop mysql
docker rm mysql

echo Install MySQL
docker run \
  -d \
  --name mysql \
  -p 3306:3306 \
  --net=host \
  --restart=always \
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

#Setup haproxy for Rancher HA

echo "#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    maxconn     100
#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    timeout                 check 10
	option httplog clf
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 1m
    timeout check           10s
    maxconn                 20000

listen stats
    bind 0.0.0.0:1936
    mode http
    stats enable
    stats hide-version
    stats realm Haproxy\ Statistics
    stats uri /
    stats auth Username:Password

backend ha-nodes
   default-server inter 3s fall 3 rise 2" > $config_path/haproxy.cfg

nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

IP=$rancher_server_ip
for i in $(seq 1 $rancher_server_node); do
    echo "   server ha-$i $IP:8080 check" >> $config_path/haproxy.cfg
    IP=$(nextip $IP)
done

if [ "$sslenabled" == 'true' ]; then
echo "
frontend main
    mode http
    bind 0.0.0.0:80
	  redirect scheme https if !{ ssl_fc }
	  bind 0.0.0.0:443 ssl crt /usr/local/etc/haproxy/haproxy.crt	
    reqadd X-Forwarded-Proto:\ https
    default_backend ha-nodes" >> $config_path/haproxy.cfg
else
echo "
frontend main
    mode http
    bind 0.0.0.0:80
    default_backend ha-nodes" >> $config_path/haproxy.cfg
fi

docker stop haproxy
docker rm haproxy
docker run -d --name haproxy --restart=always -p 80:80 -p 443:443 -p 1936:1936 -v $config_path/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro  -v /home/vagrant/haproxy.crt:/usr/local/etc/haproxy/haproxy.crt:ro haproxy:1.7

#docker run -d --name haproxy --restart=always -p 80:80 -p 443:443 -p 1936:1936 -v $config_path/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro haproxy:1.7

# Install nfs server
sudo mkdir -p /home/vagrant/nfs
sudo docker run -d --name nfs --restart=always --privileged --net=host -v /home/vagrant/nfs:/nfsshare -e SHARED_DIRECTORY=/nfsshare itsthenetwork/nfs-server-alpine:4

#Run a local registry
mkdir -p $share_path/registry
docker run -d -p 5000:5000 --restart=always --name registry  -v  $share_path/registry:/var/lib/registry  registry:2

#Run local proxy
if [ "$network_mode" == "isolated" ] || [ "$network_mode" == "airgap" ] || [ "$sslenabled" == 'true' ]; then
    docker run -d --restart=always --name proxy -p 3128:3128 minimum2scp/squid

#Setup dns proxy
echo    "
include \"/etc/bind/named.conf.local\";
acl goodclients {
        $cache_ip/24;
        localhost;
        localnets;
};

options {

        recursion yes;
        allow-query { goodclients; };

        dnssec-validation auto;

        auth-nxdomain no;    # conform to RFC1035
        listen-on-v6 { any; };
};" > /root/bind.conf

echo "        zone \"rancher.vagrant\" {
             type master;
             file \"/etc/bind/db.rancher.vagrant\";
        };" > /root/named.conf.local

echo ";
; BIND data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     ns.rancher.vagrant. root.rancher.vagrant. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      rancher.vagrant.
@       IN      A       127.0.0.1
@       IN      AAAA    ::1
@       IN      NS      ns.rancher.vagrant.
ns      IN      A       $cache_ip

;also list other computers
server     IN      A       $cache_ip" > /root/db.rancher.vagrant

    docker run -d --restart=always --name bind9 -p 53:53 -p 53:53/udp -v /root/named.conf.local:/etc/bind/named.conf.local -v /root/bind.conf:/etc/bind/named.conf -v /root/db.rancher.vagrant:/etc/bind/db.rancher.vagrant resystit/bind9:latest
fi

if [ "$network_mode" == "airgap" ] ; then

docker run -d -p 7070:7070 --restart=always --name rivapi llparse/registryranch:0.2
sleep 15
curl -Ss  "http://localhost:7070/images/$rancher_server_version" | jq -r '.images' | \
  while read key
  do
    image="${key//\"}"
    searchstring=":"
    rest=${image#*$searchstring}
    if [ "${#rest}" -gt "2" ]; then
      imageandtag=(${image//:/ })
      exists=$(curl -Ss http://$cache_ip:5000/v2/${imageandtag[0]}/tags/list | jq -r '.tags' | grep ${imageandtag[1]//,})
      if [ "${#exists}" -gt "2" ]; then
        echo "Image $image already in local cache"
      else
        docker pull ${image//,}
        docker tag ${image//,} $cache_ip:5000/${image//,}
        docker push $cache_ip:5000/${image//,}
      fi
    fi
  done
  exists=$(curl -Ss http://$cache_ip:5000/v2/server/tags/list | jq -r '.tags' | grep $rancher_server_version)
  if [ "${#exists}" -gt "2" ]; then
    echo "Image rancher/server:$rancher_server_version already in local cache"
  else
    docker pull rancher/server:$rancher_server_version
    docker tag rancher/server:$rancher_server_version $cache_ip:5000/rancher/server:$rancher_server_version
    docker push $cache_ip:5000/server:$rancher_server_version
  fi 
  exists=$(curl -Ss http://$cache_ip:5000/v2/rancher/agent/tags/list | jq -r '.tags' | grep v1.2.5)
  if [ "${#exists}" -gt "2" ]; then
    echo "Image rancher/agent:v1.2.5 already in local cache"
  else
    docker pull rancher/agent:v1.2.5
    docker tag rancher/agent:v1.2.5 $cache_ip:5000/rancher/agent:v1.2.5
    docker push $cache_ip:5000/agent:v1.2.5
  fi 
  exists=$(curl -Ss http://$cache_ip:5000/v2/curl/tags/list | jq -r '.tags' | grep latest)
  if [ "${#exists}" -gt "2" ]; then
    echo "Image appropriate/curl  already in local cache"
  else
    docker pull appropriate/curl
    docker tag appropriate/curl $cache_ip:5000/curl
    docker push $cache_ip:5000/curl
  fi
fi

# Mount /vagrant virtualbox filesystem on reboot
echo "if [ -f /var/run/vboxadd-service.pid ]; then
  mount -t vboxsf -o uid=900,gid=900,rw vagrant /vagrant
fi" > /etc/rc.local
