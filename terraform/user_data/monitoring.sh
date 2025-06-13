#!/bin/bash
apt-get update
apt-get install -y htop curl wget vim docker.io docker-compose

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

echo "Monitoring server setup initiated" > /var/log/user-data.log
