# Application Load Balancer
resource "aws_lb" "geth_rpc" {
  name               = "${var.project_name}-geth-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "geth-alb"
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-geth-alb"
  })
}

# S3 Bucket for ALB Access Logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-alb-logs-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = local.common_tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ALB Bucket Policy for Access Logs
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/geth-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/geth-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# Target Group for Geth RPC
resource "aws_lb_target_group" "geth_rpc" {
  name     = "${var.project_name}-geth-rpc-tg"
  port     = 8545
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,405" # Geth RPC returns 405 for GET requests
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-geth-rpc-tg"
  })
}

# Attach Geth instances to target group
resource "aws_lb_target_group_attachment" "geth" {
  count = length(aws_instance.geth)

  target_group_arn = aws_lb_target_group.geth_rpc.arn
  target_id        = aws_instance.geth[count.index].id
  port             = 8545
}

# ALB Listener for HTTP
resource "aws_lb_listener" "geth_rpc_http" {
  load_balancer_arn = aws_lb.geth_rpc.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.geth_rpc.arn
  }

  tags = local.common_tags
}

# ALB Listener Rule with Basic Auth (Optional)
resource "aws_lb_listener_rule" "geth_rpc_auth" {
  listener_arn = aws_lb_listener.geth_rpc_http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.geth_rpc.arn
  }

  condition {
    host_header {
      values = [aws_lb.geth_rpc.dns_name]
    }
  }

  tags = local.common_tags
}
