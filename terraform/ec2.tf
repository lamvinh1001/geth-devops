# SSH Key Pair
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-ssh-key"
  public_key = tls_private_key.this.public_key_openssh

  tags = local.common_tags
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data/bastion.sh", {
    project_name = var.project_name
  }))

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-bastion"
    Role = "bastion"
  })
}

# Geth Nodes
resource "aws_instance" "geth" {
  count = var.geth_instance_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids = [aws_security_group.geth.id]
  key_name               = aws_key_pair.this.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
    throughput  = 125
    iops        = 3000
  }

  user_data = base64encode(templatefile("${path.module}/user_data/geth.sh", {
    project_name = var.project_name
    node_index   = count.index + 1
  }))

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-geth-${count.index + 1}"
    Role = "geth"
  })
}

# Monitoring Server (Prometheus & Grafana)
resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
    throughput  = 125
    iops        = 3000
  }

  user_data = base64encode(templatefile("${path.module}/user_data/monitoring.sh", {
    project_name = var.project_name
  }))

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-monitoring"
    Role = "monitoring"
  })
}
