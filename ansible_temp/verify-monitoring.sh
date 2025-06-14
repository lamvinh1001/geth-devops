#!/bin/bash

echo "🔍 Verifying monitoring setup..."

# Check Prometheus
echo "Checking Prometheus..."
if curl -s http://54.169.158.134:9090/-/healthy | grep -q "Prometheus is Healthy"; then
    echo "✅ Prometheus is healthy"
else
    echo "❌ Prometheus is not healthy"
fi

# Check Grafana
echo "Checking Grafana..."
if curl -s http://54.169.158.134:3000/api/health | grep -q "ok"; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana is not healthy"
fi

# Check targets in Prometheus
echo "Checking Prometheus targets..."
curl -s http://54.169.158.134:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .job, health: .health, lastScrape: .lastScrape}'

echo ""
echo "🎯 Monitoring URLs:"
echo "   Prometheus: http://54.169.158.134:9090"
echo "   Grafana:    http://54.169.158.134:3000"
echo "   Targets:    http://54.169.158.134:9090/targets"
