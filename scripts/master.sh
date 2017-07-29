#!/bin/bash -x
isolated=${1:-false}
sslenabled=${2:-false}
cache_ip=${3:-172.22.101.100}
password=${4:-rancher}

echo "DOCKER_OPTS=\"\$DOCKER_OPTS --registry-mirror http://$cache_ip:4000 --insecure-registry http://$cache_ip:5000\"" >> /etc/default/docker
service docker restart

# path to a remote share
share_path=/vagrant/.vagrant/data
mkdir -p $share_path

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
  remoteurl: https://registry-1.docker.io" > $share_path/config.yml

mkdir -p $share_path/redis
echo "save 300 1
requirepass \"$password\"" > $share_path/redis/redis.conf

docker run -d --restart=always --name redis-mirror -p 6379 -v $share_path/redis:/data --entrypoint=/usr/local/bin/redis-server redis /data/redis.conf

docker run -d --restart=always -p 4000:5000 --name v2-mirror \
  -v $share_path:/var/lib/registry --link redis-mirror:redis registry:2 /var/lib/registry/config.yml

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
   default-server inter 3s fall 3 rise 2
   server ha-1 172.22.101.101:8080 check
   server ha-2 172.22.101.102:8080 check
   server ha-3 172.22.101.103:8080 check" > $share_path/haproxy.cfg

if [ "$sslenabled" == 'true' ]; then
echo "
frontend main
    mode http
    bind 0.0.0.0:80
	  redirect scheme https if !{ ssl_fc }
	  bind 0.0.0.0:443 ssl crt /usr/local/etc/haproxy/haproxy.crt	
    reqadd X-Forwarded-Proto:\ https
    default_backend ha-nodes" >> $share_path/haproxy.cfg


#SSL Termination cert for HAProxy
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
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAwLq7oWQwnSAR696FL7w2W7t/MVCioPnnJV8tFfTvIZ/zQsH4
ul9rjdv0NGLcPEXXtdDxsadn+hMWUYAqPNn2YDavpa0HhEFL/WGnUAP/XE2Vrop7
QYh/heu8BIOOQ2rAOaxlLUscDYSmA3BeIEIoDLSc+A9+xVMikc6SkSQ4qpZOF7Gv
LfbwEYs3ii7PFUTzxDbmWsOuEEyRyJ36+6fmTTIuw6rrnsCqUF7AfIEcgxEVOTxt
MoY/v8427AP+0B4pAGrY7siwqoiXtWERraVuyAwn0IkKK4LH/lH30KwzPZTV825a
E2Ob05MAg3Sbgi83BfMZQpbloJKj/MosmcXfGwIDAQABAoIBAFqp/YZIyY3A/m1F
OsZf9fplU8pxMnAj35b3FRCVLsFUq20mLsoOBVywskrKjuxTtswzRN/b7s/3lrI0
ZqpFpt9QGoUHxtdymDrUa476snBLlzSKtLz5Z3Qql0JQWOZiG5eF//q0sLezRR2t
CLqIJKsFdCpFr89H8qVA1jYtIfMs/PDechbzlFGTuxfO97AboNozg7ufB86uALgA
pNlXI4D/9duwjTaQNAE9ezI0tig0dMyjTo6haV+1cIj1schjPQc75iIYS2YAescC
r0/3mJt/xFmNu+pKt3lrdwfsFvMp8JQtb2oOwiQwqJyB9g4vDhAlGJAlRLYErQn/
JVS6MiECgYEA5KLFo7mHr7/4roPDl5KVIeXFeih5VhVy6mT6Js5vIkQGYVYW8jr7
zjXlWZqU3fZPxHNgAFUCtqehfl9/kxJ0Wfivt3tC3yPl4VxNGdSSpDZ0/N0GbGVO
VA+yqRAtLse4WkgSFeH/7AGEhXxR+Vof3FMJIobsWzs+5TNfzD+xUzMCgYEA18vQ
5o8CQ6WnfOwYjOVSmHnRJaf+86Q+x7Tv/7zKhSjpcxZ4SFCCbR9C6Pgk3zNFPBq9
U59z9TsxSS19LIh+xIfQiugzjPPLtYFWnDQ5CGvjmGo3wWV+9Gd/kUkUwd8o/p2+
DY83+Zk0FtfzENNe4lYnMEzIAuMQufcRM4e0RHkCgYEAs+KpU37Gle2ZkFzVR+0p
bskkTU+I38TybB7UfjHPWIti5bRhS2ZC9eSLtasc02JXMj6AWuKHxwQu2In0itdr
OdqjDd5qJ7xLwrrnYppQYekCtGyGAETYkuTi8YdrtTGoB0hLCnKM87fh91BwApr5
FFU0i7jSP5lmi9iW19GJB+cCgYEArEkyAFEeyqlf3fGU7DBOUCO5oinM9/IimUjQ
78lnmwZ903+WCo4Ug1CZF+y9a2HAnervSuscJibbA4SI0lwrcXbJPY2DUr513fRk
FJPxENMqQ05SM1p4EGLtSy4gn2Quk5GW4bZ9Rw5UswQ4MC/BKk0EPqCecwecHAyw
NAbdGmkCgYEAsjTNrP9lyUgCn3Xz2Q1dEKMBLICXB7RvrcOQHZGRI/ptVmKOh7FT
+cg6f1otVPm1NCOEng633lJ3EduHcqRrqHs7PWJ9QoKqgyLK6jObU03KGE4kpiha
M8HpKBkMOpDEh5be8camqqf/0eE51fEpwYDjZQYlfQ0dtWM3u53BDb4=
-----END RSA PRIVATE KEY-----
" > $share_path/haproxy.crt

else
echo"
frontend main
    mode http
    bind 0.0.0.0:80
    default_backend ha-nodes" >> $share_path/haproxy.cfg
fi

docker stop haproxy
docker rm haproxy
docker run -d --name haproxy --restart=always -p 80:80 -p 443:443 -p 1936:1936 -v /vagrant/.vagrant/data/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro  -v /vagrant/.vagrant/data/haproxy.crt:/usr/local/etc/haproxy/haproxy.crt:ro haproxy:1.7

#docker run -d --name haproxy --restart=always -p 80:80 -p 443:443 -p 1936:1936 -v $share_path/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro haproxy:1.7

# Install nfs server
sudo mkdir -p /home/vagrant/nfs
sudo docker run -d --name nfs --restart=always --privileged --net=host -v /home/vagrant/nfs:/nfsshare -e SHARED_DIRECTORY=/nfsshare itsthenetwork/nfs-server-alpine:4

#Run a local registry
mkdir -p $share_path/registry
docker run -d -p 5000:5000 --restart=always --name registry  -v  $share_path/registry:/var/lib/registry  registry:2

#Run local proxy
if [ "$isolated" == 'true' || "$sslenabled" == 'true']; then
    docker run -d --restart=always --name proxy -p 3128:3128 minimum2scp/squid

#Setup dns proxy
echo    "
include \"/etc/bind/named.conf.local\";
acl goodclients {
        172.22.101.0/24;
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
ns      IN      A       172.22.101.100

;also list other computers
server     IN      A       172.22.101.100" > /root/db.rancher.vagrant

    docker run -d --name bind9 -p 53:53 -p 53:53/udp -v /root/named.conf.local:/etc/bind/named.conf.local -v /root/bind.conf:/etc/bind/named.conf -v /root/db.rancher.vagrant:/etc/bind/db.rancher.vagrant resystit/bind9:latest
fi