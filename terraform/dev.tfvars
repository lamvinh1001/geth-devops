# Copy this file to terraform.tfvars and customize the values

aws_region    = "ap-southeast-1"
project_name  = "ethereum-devops"
environment   = "dev"
vpc_cidr      = "10.0.0.0/16"
instance_type = "t3.medium"

# Restrict SSH access to your IP for security
allowed_ssh_ips = ["171.252.106.73/32"]

# Number of Geth nodes (minimum 3 for proper blockchain setup)
geth_instance_count = 1
