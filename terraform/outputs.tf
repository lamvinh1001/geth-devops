# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

# EC2 Outputs
output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host"
  value       = aws_instance.bastion.id
}

output "geth_instance_ids" {
  description = "Instance IDs of Geth nodes"
  value       = aws_instance.geth[*].id
}

output "geth_private_ips" {
  description = "Private IPs of Geth nodes"
  value       = aws_instance.geth[*].private_ip
}

output "monitoring_instance_id" {
  description = "Instance ID of monitoring server"
  value       = aws_instance.monitoring.id
}

output "monitoring_public_ip" {
  description = "Public IP of monitoring server"
  value       = aws_instance.monitoring.public_ip
}

# # Load Balancer Outputs
# output "alb_dns_name" {
#   description = "DNS name of the Application Load Balancer"
#   value       = aws_lb.geth_rpc.dns_name
# }

# output "alb_zone_id" {
#   description = "Hosted zone ID of the Application Load Balancer"
#   value       = aws_lb.geth_rpc.zone_id
# }

# output "geth_rpc_endpoint" {
#   description = "Geth RPC endpoint URL"
#   value       = "http://${aws_lb.geth_rpc.dns_name}"
# }

# Security Group Outputs
output "security_group_ids" {
  description = "IDs of all security groups"
  value = {
    bastion    = aws_security_group.bastion.id
    geth       = aws_security_group.geth.id
    alb        = aws_security_group.alb.id
    monitoring = aws_security_group.monitoring.id
  }
}

# SSH Key Outputs
output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.this.key_name
}

output "ssh_private_key_secret_arn" {
  description = "ARN of the SSH private key in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.ssh_private_key.arn
  sensitive   = true
}

# Monitoring Access
output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL (internal access)"
  value       = "http://${aws_instance.monitoring.private_ip}:9090"
}

# Connection Instructions
# output "connection_instructions" {
#   description = "Instructions for connecting to the infrastructure"
#   value       = <<-EOT
#     SSH to bastion: ssh -i ~/.ssh/${aws_key_pair.this.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}

#     From bastion, connect to Geth nodes:
#     ${join("\n    ", formatlist("ssh ubuntu@%s", aws_instance.geth[*].private_ip))}

#     Grafana Dashboard: http://${aws_instance.monitoring.public_ip}:3000
#     Geth RPC Endpoint: http://${aws_lb.geth_rpc.dns_name}

#     Note: Download the private key from AWS Secrets Manager:
#     aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.ssh_private_key.name} --query SecretString --output text > ~/.ssh/${aws_key_pair.this.key_name}.pem
#     chmod 600 ~/.ssh/${aws_key_pair.this.key_name}.pem
#   EOT
# }
