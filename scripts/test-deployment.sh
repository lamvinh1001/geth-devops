#!/bin/bash
set -e

echo "🧪 Testing Deployment"

cd terraform

# Get outputs
ALB_DNS=$(terraform output -raw alb_dns_name)
MONITORING_IP=$(terraform output -raw monitoring_instance_public_ip)

echo "🔍 Testing Geth RPC Endpoint..."
curl -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://$ALB_DNS && echo "✅ RPC test passed" || echo "❌ RPC test failed"

echo "🔍 Testing Prometheus..."
curl -f http://$MONITORING_IP:9090/-/healthy && echo "✅ Prometheus healthy" || echo "❌ Prometheus unhealthy"

echo "🔍 Testing Grafana..."
curl -f http://$MONITORING_IP:3000/api/health && echo "✅ Grafana healthy" || echo "❌ Grafana unhealthy"

echo "📊 Access URLs:"
echo "  Geth RPC: http://$ALB_DNS"
echo "  Prometheus: http://$MONITORING_IP:9090"
echo "  Grafana: http://$MONITORING_IP:3000 (admin/admin)"
