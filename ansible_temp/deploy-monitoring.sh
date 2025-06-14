#!/bin/bash
set -e

echo "🚀 Starting monitoring deployment..."

# Check if private key exists
if [ ! -f ~/.ssh/ethereum-devops-ssh-key.pem ]; then
    echo "❌ SSH private key not found at ~/.ssh/ethereum-devops-ssh-key.pem"
    echo "Please retrieve it from AWS Secrets Manager and place it there with proper permissions (600)"
    exit 1
fi

# Set correct permissions for SSH key
chmod 600 ~/.ssh/ethereum-devops-ssh-key.pem

# Test connectivity to bastion
echo "🔍 Testing bastion connectivity..."
if ! ssh -i ~/.ssh/ethereum-devops-ssh-key.pem -o ConnectTimeout=10 ubuntu@54.255.190.26 'echo "Bastion accessible"'; then
    echo "❌ Cannot connect to bastion host"
    exit 1
fi

# Test connectivity to geth node through bastion
echo "🔍 Testing geth node connectivity through bastion..."
if ! ssh -i ~/.ssh/ethereum-devops-ssh-key.pem -o ConnectTimeout=10 -o ProxyCommand="ssh -W %h:%p -q ubuntu@54.255.190.26 -i ~/.ssh/ethereum-devops-ssh-key.pem" ubuntu@10.0.1.36 'echo "Geth node accessible"'; then
    echo "❌ Cannot connect to geth node through bastion"
    exit 1
fi

echo "✅ Connectivity tests passed"

# Run Ansible playbook
echo "🎭 Running Ansible playbook..."
ansible-playbook -i inventory/hosts.yml playbooks/monitoring.yml -v

echo "🎉 Monitoring deployment completed!"
echo ""
echo "📊 Access your monitoring:"
echo "   Prometheus: http://54.169.158.134:9090"
echo "   Grafana:    http://54.169.158.134:3000 (admin/admin123)"
echo ""
echo "🔍 Verify services:"
echo "   Node Exporter metrics: curl http://10.0.1.36:9100/metrics (through bastion)"
echo "   Prometheus targets: http://54.169.158.134:9090/targets"
