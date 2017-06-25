#!/bin/sh

token=$1
env_file="/etc/etcd2.env"
ip=`ifconfig $2 | awk '/inet / && $2!="127.0.0.1" { print $2 }'`

[[ -z "$ip" ]] && echo "ERROR: IP address could not be determined!" && exit 1

echo "Creating ectd2 environment file targeting IP address $ip ..."

cat << EOF > $env_file
ETCD_DISCOVERY="https://discovery.etcd.io/$token"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$ip:2380"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379,http://0.0.0.0:4001"
ETCD_LISTEN_PEER_URLS="http://$ip:2380"
EOF
