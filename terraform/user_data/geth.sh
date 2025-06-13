#!/bin/bash
apt-get update
apt-get install -y htop curl wget vim

# Create geth user
useradd -m -s /bin/bash geth

# Create directories
mkdir -p /opt/geth/{bin,data,config}
chown -R geth:geth /opt/geth

echo "Geth node ${node_index} setup initiated" > /var/log/user-data.log
