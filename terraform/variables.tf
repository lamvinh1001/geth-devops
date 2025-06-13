variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ethereum-devops"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "allowed_ssh_ips" {
  description = "List of IPs allowed to SSH"
  type        = list(string)
  default     = ["171.252.106.73/32"] # Restrict 0.0.0.0 in production
}

variable "geth_instance_count" {
  description = "Number of Geth nodes"
  type        = number
  default     = 1
}
