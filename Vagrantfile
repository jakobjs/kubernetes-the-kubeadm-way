# -*- mode: ruby -*-
# vi:set ft=ruby sw=2 ts=2 sts=2:

# Define the number of master and worker nodes
NUM_MASTER_NODE = 1
NUM_WORKER_NODE = 1

# Node network
IP_NW = "192.168.10."
MASTER_IP_START = 100
WORKER_IP_START = 200
LB_IP_START = 10

Vagrant.configure("2") do |config|
  #config.vm.box = "ubuntu/focal64"
  config.vm.box = "generic/ubuntu2004"

  # Provision Load Balancer Node
  config.vm.define "loadbalancer" do |node|
    node.vm.provider "virtualbox" do |vb|
      vb.name = "kubernetes-the-kubeadm-way-lb"
      vb.memory = 512
      vb.cpus = 1
    end
    node.vm.hostname = "loadbalancer"
    node.vm.network :private_network, ip: IP_NW + "#{LB_IP_START}"
	  #node.vm.network "forwarded_port", guest: 22, host: 2740

    node.vm.provision "environment-file", type: "file", source: "kubernetes-the-kubeadm-way.env", destination: "/tmp/kubernetes-the-kubeadm-way.sh"
    node.vm.provision "setup-environment", type: "shell", inline: "mv /tmp/kubernetes-the-kubeadm-way.sh /etc/profile.d/"

    node.vm.provision "setup-ssh", type: "shell", inline: $setup_ssh, privileged: false
    node.vm.provision "setup-hosts", type: "shell", inline: $setup_hosts

    node.vm.provision "setup-haproxy", type: "shell", inline: $setup_loadbalancer

  end # loadbalancer

  # Provision Master Nodes
  (1..NUM_MASTER_NODE).each do |i|
    config.vm.define "master-#{i}" do |node|
      # Name shown in the GUI
      node.vm.provider "virtualbox" do |vb|
        vb.name = "kubernetes-the-kubeadm-way-master-#{i}"
        vb.memory = 2048
        vb.cpus = 2
      end
      node.vm.hostname = "master-#{i}"
      node.vm.network :private_network, ip: IP_NW + "#{MASTER_IP_START + i}"
      #node.vm.network "forwarded_port", guest: 22, host: "#{2750 + i}"

      node.vm.provision "environment-file", type: "file", source: "kubernetes-the-kubeadm-way.env", destination: "/tmp/kubernetes-the-kubeadm-way.sh"
      node.vm.provision "setup-environment", type: "shell", inline: "mv /tmp/kubernetes-the-kubeadm-way.sh /etc/profile.d/"
      
      node.vm.provision "setup-ssh", type: "shell", inline: $setup_ssh, privileged: false
      node.vm.provision "setup-hosts", type: "shell", inline: $setup_hosts

      node.vm.provision "allow-bridge-nf-traffic", type: "shell", inline: $allow_bridge_nf_traffic
      node.vm.provision "install-docker", type: "shell", inline: $install_docker
      node.vm.provision "install-nfs-client", type: "shell", inline: $install_nfs_client
      node.vm.provision "install-kubeadm", type: "shell", inline: $install_kubeadm

      node.vm.provision "setup-nfs", type: "shell", inline: $setup_nfs if i == 1
      
      node.vm.provision "cluster_init", type: "shell", inline: $cluster_init if i == 1
      node.vm.provision "cluster_join", type: "shell", inline: $cluster_join_control_plane unless i == 1

      node.vm.provision "kubernetes-metrics-server", type: "shell", inline: $kubernetes_metrics_server, privileged: false if i == 1

    end
  end # masters

  # Provision Worker Nodes
  (1..NUM_WORKER_NODE).each do |i|
    config.vm.define "worker-#{i}" do |node|
      node.vm.provider "virtualbox" do |vb|
        vb.name = "kubernetes-the-kubeadm-way-worker-#{i}"
        vb.memory = 4096
        vb.cpus = 4
      end
      node.vm.hostname = "worker-#{i}"
      node.vm.network :private_network, ip: IP_NW + "#{WORKER_IP_START + i}"
      #node.vm.network "forwarded_port", guest: 22, host: "#{2750 + i}"

      node.vm.provision "environment-file", type: "file", source: "kubernetes-the-kubeadm-way.env", destination: "/tmp/kubernetes-the-kubeadm-way.sh"
      node.vm.provision "setup-environment", type: "shell", inline: "mv /tmp/kubernetes-the-kubeadm-way.sh /etc/profile.d/"
      
      node.vm.provision "setup-ssh", type: "shell", inline: $setup_ssh, privileged: false
      node.vm.provision "setup-hosts", type: "shell", inline: $setup_hosts

      node.vm.provision "allow-bridge-nf-traffic", type: "shell", inline: $allow_bridge_nf_traffic
      node.vm.provision "install-docker", type: "shell", inline: $install_docker
      node.vm.provision "install-nfs-client", type: "shell", inline: $install_nfs_client
      node.vm.provision "install-kubeadm", type: "shell", inline: $install_kubeadm

      node.vm.provision "cluster_join", type: "shell", inline: $cluster_join_worker_node

    end
  end # workers

end


$setup_ssh = <<SCRIPT
set -x
if [ -r /vagrant/ssh/id_ed25519 ]; then
  cp /vagrant/ssh/id_* ~/.ssh/
  cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
else  
  ssh-keygen -t ed25519 -a 100 -q -N "" -f ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
  mkdir -p /vagrant/ssh
  cp ~/.ssh/id_* /vagrant/ssh/
fi
SCRIPT


$setup_hosts = <<SCRIPT
set -euxo pipefail
# remove 127.0.1.1 and ubuntu-bionic entry
sed -e '/^127.0.1.1.*/d' -i /etc/hosts
sed -e '/^.*ubuntu-bionic.*/d' -i /etc/hosts

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
SCRIPT

$install_nfs_client = <<SCRIPT
sudo apt-get -qq update && sudo apt-get -qq install -y nfs-common
SCRIPT

$setup_nfs = <<SCRIPT
export NFS_ROOT=/var/nfs
sudo apt-get -qq update && sudo apt-get -qq install -y nfs-kernel-server
sudo mkdir -p ${NFS_ROOT}
sudo chown nobody:nogroup ${NFS_ROOT}
sudo chmod a+rwx ${NFS_ROOT}

cat > /etc/exports <<EOF
${NFS_ROOT}    *(rw,sync,no_subtree_check)
EOF

sudo systemctl enable nfs-server
sudo systemctl restart nfs-server
SCRIPT

$install_docker = <<SCRIPT
set -x
# Install docker
curl -fsSL https://get.docker.com | bash

# Give vagrant user access to docker socket
usermod -aG docker vagrant

# Setup daemon
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker
systemctl daemon-reload
systemctl restart docker
SCRIPT


$allow_bridge_nf_traffic = <<SCRIPT
set -euxo pipefail

lsmod | grep br_netfilter || modprobe br_netfilter

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system
SCRIPT


$setup_loadbalancer = <<SCRIPT
set -euxo pipefail

LB_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f 1)
MASTER_NODES=$(grep master /etc/hosts | awk '{print $2}')

## Run on Loadbalancer

#Install HAProxy
sudo apt-get -qq update && sudo apt-get -qq install -y haproxy

cat <<EOF | sudo tee -a /etc/haproxy/haproxy.cfg 

listen stats
    bind :9999
    mode http
    stats enable
    stats hide-version
    stats uri /stats

frontend kubernetes
    bind ${LB_IP}:6443
    mode tcp
    option tcplog
    stats uri /k8sstats
    default_backend kubernetes-control-plane

backend kubernetes-control-plane
    mode tcp
    option tcp-check
    balance roundrobin
EOF

for instance in ${MASTER_NODES}; do
  cat <<EOF | sudo tee -a /etc/haproxy/haproxy.cfg
    server ${instance} $(grep ${instance} /etc/hosts | awk '{print $1}'):6443 check fall 3 rise 2
EOF
done

sudo systemctl restart haproxy
systemctl status --no-pager haproxy

# Verify
nc -zv ${LB_IP} 6443
SCRIPT


$install_kubeadm = <<SCRIPT
set -euxo pipefail
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
SCRIPT


$cluster_init = <<SCRIPT
set -euxo pipefail
NODE_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

cat <<EOF > cluster-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  serviceSubnet: "${CLUSTER_SERVICE_CIDR}"
  podSubnet: "${CLUSTER_POD_CIDR}"
controlPlaneEndpoint: "${LOADBALANCER_IP}"
apiServer:
  extraArgs:
    advertise-address: "${NODE_IP}"
#---
#apiVersion: kubelet.config.k8s.io/v1beta1
#kind: KubeletConfiguration
#serverTLSBootstrap: true
EOF

# Kubeadm Init
### NOTE THIS IS STUPID. Pre pull the images, then add a new default route so that etcd uses the correct IP. Delete the dummy default route after.
kubeadm config images pull
ip route add default via ${NODE_IP} metric 10
kubeadm init --config=cluster-config.yaml \
  --upload-certs \
  | tee /vagrant/kubeadm-init.log

ip route delete default via ${NODE_IP}


# Edit the coredns deployment so it serves the /etc/hosts from it's host so pods can resolve the master/worker nodes
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n kube-system patch deployment coredns --patch '{"spec": {"template": {"spec": {"containers": [{"name": "coredns", "volumeMounts": [{"name": "hosts-volume", "mountPath": "/etc/hosts"}] }], "volumes": [{ "name": "hosts-volume", "hostPath": {"path": "/etc/hosts"} }] } } } }'

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        hosts {
          fallthrough
        }
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
EOF


# Set up CNI network addon
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=${CLUSTER_POD_CIDR}"

# Setup join scripts for additional master and worker nodes
MASTER_JOIN_CMD=$(grep -e "kubeadm join" -A3 /vagrant/kubeadm-init.log | sed 's/[ /t]*//' | head -3)
WORKER_JOIN_CMD=$(grep -e "kubeadm join" -A3 /vagrant/kubeadm-init.log | sed 's/[ /t]*//' | tail -2)

cat <<EOF >/vagrant/join-master.sh
#!/bin/bash
set -x
NODE_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

### NOTE THIS IS STUPID. Pre pull the images, then add a new default route so that etcd uses the correct IP. Delete the dummy default route after.
kubeadm config images pull
ip route add default via ${NODE_IP} metric 10

${MASTER_JOIN_CMD}

ip route delete default via ${NODE_IP}
EOF

cat <<EOF >/vagrant/join-worker.sh
#!/bin/bash
set -x
NODE_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

### NOTE THIS IS STUPID. Pre pull the images, then add a new default route so that etcd uses the correct IP. Delete the dummy default route after.
kubeadm config images pull
ip route add default via ${NODE_IP} metric 10

${WORKER_JOIN_CMD}

ip route delete default via ${NODE_IP}
EOF

chmod +x /vagrant/join-master.sh /vagrant/join-worker.sh

# Set up admin kubeconfig for the vagrant user
sudo --user=vagrant mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
# Copying the admin kubeconfig to shared location
cp /etc/kubernetes/admin.conf /vagrant/admin.kubeconfig
SCRIPT

$cluster_join_control_plane = <<SCRIPT
set -x
/vagrant/join-master.sh

# Set up admin kubeconfig for the vagrant user
sudo --user=vagrant mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
SCRIPT


$cluster_join_worker_node = <<SCRIPT
set -x
/vagrant/join-worker.sh
SCRIPT

$kubernetes_metrics_server = <<SCRIPT
curl -sSL https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.7/components.yaml | \
sed -E 's%apiregistration.k8s.io/v1beta1%apiregistration.k8s.io/v1%g' | \
sed -E '/args:/a \\          - --kubelet-insecure-tls' | \
kubectl apply -f -
SCRIPT
