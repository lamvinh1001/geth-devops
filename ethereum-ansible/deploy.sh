#!/bin/bash
set -e

echo "=== Ethereum DevOps Deployment Script ==="
echo "This script will deploy the complete Ethereum private network with monitoring"
echo ""

# Check if SSH key exists
if [ ! -f ~/.ssh/ethereum-devops-ssh-key.pem ]; then
    echo "ERROR: SSH key not found at ~/.ssh/ethereum-devops-ssh-key.pem"
    echo "Please ensure your SSH private key is available at this location"
    exit 1
fi

# Set correct permissions on SSH key
chmod 600 ~/.ssh/ethereum-devops-ssh-key.pem

# Test connectivity to bastion host
echo "Testing connectivity to bastion host..."
ssh -i ~/.ssh/ethereum-devops-ssh-key.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@47.129.36.151 "echo 'Bastion host accessible'" || {
    echo "ERROR: Cannot connect to bastion host"
    exit 1
}

echo "Connectivity test passed!"
echo ""

# Run Ansible playbook
echo "Starting Ansible deployment..."
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml -v

echo ""
echo "=== Deployment Complete ==="
echo ""
