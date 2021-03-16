#!/usr/bin/env bash
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