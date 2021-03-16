#!/usr/bin/env bash
set -euxo pipefail
ETH=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
NODE_IP=$(ip addr show $ETH | grep "inet " | awk '{print $2}' | cut -d/ -f1)

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
#ip route add default via ${NODE_IP} metric 10
kubeadm init --config=cluster-config.yaml \
  --upload-certs \
  | tee /vagrant/kubeadm-init.log

#ip route delete default via ${NODE_IP}

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
ETH=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
NODE_IP=$(ip addr show $ETH | grep "inet " | awk '{print $2}' | cut -d/ -f1)

### NOTE THIS IS STUPID. Pre pull the images, then add a new default route so that etcd uses the correct IP. Delete the dummy default route after.
kubeadm config images pull
#ip route add default via ${NODE_IP} metric 10

${MASTER_JOIN_CMD}

#ip route delete default via ${NODE_IP}
EOF

cat <<EOF >/vagrant/join-worker.sh
#!/bin/bash
set -x
ETH=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
NODE_IP=$(ip addr show $ETH | grep "inet " | awk '{print $2}' | cut -d/ -f1)

### NOTE THIS IS STUPID. Pre pull the images, then add a new default route so that etcd uses the correct IP. Delete the dummy default route after.
kubeadm config images pull
#ip route add default via ${NODE_IP} metric 10

${WORKER_JOIN_CMD}

#ip route delete default via ${NODE_IP}
EOF

chmod +x /vagrant/join-master.sh /vagrant/join-worker.sh

# Set up admin kubeconfig for the vagrant user
sudo --user=vagrant mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
# Copying the admin kubeconfig to shared location
cp /etc/kubernetes/admin.conf /vagrant/admin.kubeconfig