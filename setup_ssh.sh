#!/usr/bin/env bash
set -x
if [ -r /vagrant/ssh/id_ed25519 ]; then
  cp /vagrant/ssh/id_* ~/.ssh/
  cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
else  
  ssh-keygen -t ed25519 -a 100 -q -N "" -f ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
  sudo mkdir -p /vagrant/ssh
  sudo chmod 777 /vagrant/ssh
  cp ~/.ssh/id_* /vagrant/ssh/
fi
