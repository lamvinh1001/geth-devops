# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get current caller identity
data "aws_caller_identity" "current" {}

# Get current region
data "aws_region" "current" {}
