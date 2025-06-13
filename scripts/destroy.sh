#!/bin/bash
set -e

echo "🔥 Destroying DevOps Challenge Infrastructure"

read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Destruction cancelled"
    exit 1
fi

echo "💥 Destroying Terraform infrastructure..."
cd terraform
terraform destroy -auto-approve
cd ..

echo "🧹 Cleanup complete!"
