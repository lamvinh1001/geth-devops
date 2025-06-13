# DevOps Challenge: Private Ethereum Network with Monitoring

This project implements a comprehensive DevOps solution featuring a private Ethereum blockchain network with monitoring and automated deployment.

## Architecture Overview

- **Infrastructure**: AWS VPC with public/private subnets, NAT Gateway, Internet Gateway
- **Compute**: 3 Geth nodes in private subnets, monitoring server, bastion host
- **Load Balancing**: Application Load Balancer for RPC endpoint access
- **Monitoring**: Prometheus metrics collection, Grafana visualization
- **Security**: Security Groups, SSH key management via AWS Secrets Manager
- **Automation**: Terraform for infrastructure, Ansible for configuration, GitHub Actions for CI/CD

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Ansible >= 4.0
- Python 3.8+ with boto3

### Deployment Steps

1. **Clone and Setup**
   ```bash
   git clone <repository>
   cd GETH-DEVOPS
   ```

2. **Deploy Infrastructure**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configure Services**
   ```bash
   cd ../ansible
   # Retrieve SSH key from AWS Secrets Manager
   aws secretsmanager get-secret-value \
     --secret-id ethereum-devops-ssh-private-key \
     --query SecretString \
     --output text > ~/.ssh/ethereum-devops-deployer.pem
   chmod 600 ~/.ssh/ethereum-devops-deployer.pem
   
   # Run Ansible playbook
   ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
   ```

4. **Access Services**
   - **Geth RPC**: `http://<alb-dns-name>/`
   - **Prometheus**: `http://<monitoring-ip>:9090`
   - **Grafana**: `http://<monitoring-ip>:3000` (admin/admin)

## Project Structure

```
GETH-DEVOPS/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       ├── security_groups/
│       ├── ec2/
│       └── alb/
├── ansible/                   # Configuration Management
│   ├── ansible.cfg
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
│       ├── geth_node/
│       ├── prometheus_server/
│       ├── grafana_server/
│       └── node_exporter/
├── .github/workflows/         # CI/CD Pipeline
│   └── deploy.yml
├── monitoring/                # Monitoring configurations
├── scripts/                   # Utility scripts
└── docs/                     # Documentation
```

## Security Features

- **Network Isolation**: Private subnets for Geth nodes
- **Access Control**: Security Groups with minimal required ports
- **SSH Security**: Key-based authentication, bastion host access
- **Secrets Management**: AWS Secrets Manager for sensitive data
- **Encryption**: EBS volumes encrypted at rest

## Monitoring

- **Node Exporter**: System metrics from all instances
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Custom Dashboards**: Ethereum-specific metrics

## CI/CD Pipeline

The GitHub Actions workflow includes:
1. **Terraform**: Infrastructure provisioning
2. **Ansible**: Service configuration
3. **Testing**: Health checks and validation
4. **Security**: Secrets management and secure deployments

## Customization

### Modifying the Network

- Edit `terraform/variables.tf` for network configuration
- Adjust `ansible/group_vars/all.yml` for service settings

### Adding Nodes

- Increase the count in `terraform/modules/ec2/main.tf`
- Update Ansible inventory to include new nodes

### Security Hardening

- Restrict `allowed_ssh_ips` in variables
- Enable additional security features in security groups
- Configure SSL/TLS for web interfaces

## Troubleshooting

### Common Issues

1. **Geth nodes not connecting**
   - Check security groups allow P2P communication
   - Verify static-nodes.json configuration

2. **Monitoring not showing data**
   - Ensure Node Exporter is running on all nodes
   - Check Prometheus targets page

3. **RPC endpoint not accessible**
   - Verify ALB health checks are passing
   - Check Geth RPC configuration

### Useful Commands

```bash
# Check Geth status
sudo systemctl status geth

# View Geth logs
sudo journalctl -u geth -f

# Test RPC endpoint
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://<endpoint>

# Check Prometheus targets
curl http://<monitoring-ip>:9090/api/v1/targets
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License.
