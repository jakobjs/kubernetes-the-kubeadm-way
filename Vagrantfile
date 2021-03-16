# -*- mode: ruby -*-
# vi:set ft=ruby sw=2 ts=2 sts=2:

# https://stackoverflow.com/questions/19648088/pass-environment-variables-to-vagrant-shell-provisioner

# Define the number of master and worker nodes
NUM_MASTER_NODE = 1
NUM_WORKER_NODE = 1

# Node network
IP_NW = "192.168.10."
MASTER_IP_START = 100
WORKER_IP_START = 200
LB_IP_START = 10

Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"

  # Provision Load Balancer Node
  config.vm.define "loadbalancer" do |node|
    node.vm.provider "virtualbox" do |vb|
      vb.name = "kubernetes-the-kubeadm-way-lb"
      vb.memory = 512
      vb.cpus = 1
      vb.linked_clone = true
    end
    node.vm.hostname = "loadbalancer"
    node.vm.network :private_network, ip: IP_NW + "#{LB_IP_START}"
	  #node.vm.network "forwarded_port", guest: 22, host: 2740
    node.vm.provision "environment-file", type: "file", source: "kubernetes-the-kubeadm-way.env", destination: "/tmp/kubernetes-the-kubeadm-way.sh"
    node.vm.provision "setup-environment", type: "shell", inline: "mv /tmp/kubernetes-the-kubeadm-way.sh /etc/profile.d/"

    node.vm.provision "setup-ssh", type: "shell", path: "setup_ssh.sh", privileged: false
    node.vm.provision "setup-hosts", type: "shell", path: "setup_hosts.sh"

    node.vm.provision "setup-haproxy", type: "shell", path: "setup_loadbalancer.sh"
  end # loadbalancer

  # Provision Master Nodes
  (1..NUM_MASTER_NODE).each do |i|
    config.vm.define "master-#{i}" do |node|
      # Name shown in the GUI
      node.vm.provider "virtualbox" do |vb|
        vb.name = "kubernetes-the-kubeadm-way-master-#{i}"
        vb.memory = 2048
        vb.cpus = 2
        vb.linked_clone = true
      end
      node.vm.hostname = "master-#{i}"
      node.vm.network :private_network, ip: IP_NW + "#{MASTER_IP_START + i}"
      #node.vm.network "forwarded_port", guest: 22, host: "#{2750 + i}"

      node.vm.provision "environment-file", type: "file", source: "kubernetes-the-kubeadm-way.env", destination: "/tmp/kubernetes-the-kubeadm-way.sh"
      node.vm.provision "setup-environment", type: "shell", inline: "mv /tmp/kubernetes-the-kubeadm-way.sh /etc/profile.d/"

      node.vm.provision "setup-ssh", type: "shell", path: "setup_ssh.sh", privileged: false
      node.vm.provision "setup-hosts", type: "shell", path: "setup_hosts.sh"

      node.vm.provision "allow-bridge-nf-traffic", type: "shell", inline: $allow_bridge_nf_traffic
      node.vm.provision "install-docker", type: "shell", path: "setup_docker.sh"
      node.vm.provision "install-nfs-client", type: "shell", inline: $install_nfs_client
      node.vm.provision "install-kubeadm", type: "shell", path: "setup_kubeadm.sh"

      node.vm.provision "setup-nfs", type: "shell", path: "setup_nfs.sh" if i == 1
      
      node.vm.provision "cluster_init", type: "shell", path: "setup_cluster.sh" if i == 1
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
        vb.linked_clone = true
      end
      node.vm.hostname = "worker-#{i}"
      node.vm.network :private_network, ip: IP_NW + "#{WORKER_IP_START + i}"
      #node.vm.network "forwarded_port", guest: 22, host: "#{2750 + i}"

      node.vm.provision "environment-file", type: "file", source: "kubernetes-the-kubeadm-way.env", destination: "/tmp/kubernetes-the-kubeadm-way.sh"
      node.vm.provision "setup-environment", type: "shell", inline: "mv /tmp/kubernetes-the-kubeadm-way.sh /etc/profile.d/"
      
      node.vm.provision "setup-ssh", type: "shell", path: "setup_ssh.sh" , privileged: false
      node.vm.provision "setup-hosts", type: "shell", path: "setup_hosts.sh"

      node.vm.provision "allow-bridge-nf-traffic", type: "shell", inline: $allow_bridge_nf_traffic
      node.vm.provision "install-docker", type: "shell", path: "setup_docker.sh"
      node.vm.provision "install-nfs-client", type: "shell", inline: $install_nfs_client
      node.vm.provision "install-kubeadm", type: "shell", path: "setup_kubeadm.sh"

      node.vm.provision "cluster_join", type: "shell", inline: $cluster_join_worker_node

    end
  end # workers
end

$install_nfs_client = <<SCRIPT
sudo apt-get -qq update && sudo apt-get -qq install -y nfs-common
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
