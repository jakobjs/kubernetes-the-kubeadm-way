#!/usr/bin/env bash
set -euxo pipefail
swapoff -a  
# remove 127.0.1.1 and ubuntu-bionic entry
sed -e '/^127.0.1.1.*/d' -i /etc/hosts
sed -e '/^.*ubuntu-focal.*/d' -i /etc/hosts

# Update /etc/hosts about other hosts
echo "#{IP_NW}#{LB_IP_START} kubernetes lb loadbalancer" >> /etc/hosts

for i in {1..#{NUM_MASTER_NODE}}; do
  NR=$(expr #{MASTER_IP_START} + ${i})
  echo "#{IP_NW}${NR} master-${i}" >> /etc/hosts
done

for i in {1..#{NUM_WORKER_NODE}}; do
  NR=$(expr #{WORKER_IP_START} + ${i})
  echo "#{IP_NW}${NR} worker-${i}" >> /etc/hosts
done
