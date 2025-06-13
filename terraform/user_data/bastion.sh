#!/bin/bash
apt-get update
apt-get install -y htop curl wget vim

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Configure SSH forwarding
echo "Host *" >> /home/ubuntu/.ssh/config
echo "    StrictHostKeyChecking no" >> /home/ubuntu/.ssh/config
echo "    UserKnownHostsFile=/dev/null" >> /home/ubuntu/.ssh/config
chown ubuntu:ubuntu /home/ubuntu/.ssh/config

# Install Ansible
apt-get install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

echo "Bastion host setup completed" > /var/log/user-data.log
