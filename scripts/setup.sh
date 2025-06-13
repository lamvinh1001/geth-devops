#!/bin/bash
set -e

echo "🚀 Setting up DevOps Challenge Environment"

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed"; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo "❌ Ansible is required but not installed"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed"; exit 1; }

echo "✅ Prerequisites check passed"

# Initialize Terraform
echo "📦 Initializing Terraform..."
cd terraform
terraform init
cd ..

echo "🎉 Setup complete! You can now run:"
echo "  terraform plan (from terraform/ directory)"
echo "  terraform apply (from terraform/ directory)" 
echo "  ansible-playbook playbooks/site.yml (from ansible/ directory)"
