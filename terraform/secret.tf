
# Store private key in AWS Secrets Manager
resource "aws_secretsmanager_secret" "ssh_private_key" {
  name                    = "${var.project_name}-private-key"
  description             = "SSH private key for ${var.project_name} infrastructure"
  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "ssh_private_key" {
  secret_id     = aws_secretsmanager_secret.ssh_private_key.id
  secret_string = tls_private_key.this.private_key_pem
}
