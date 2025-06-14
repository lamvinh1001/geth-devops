
# WAF Configuration for ALB to allow only specific IPs to protect Geth RPC
variable "whitelisted_ips" {
  type    = list(string)
  default = ["171.252.106.73/32"] # Thay bằng IP của bạn
}

resource "aws_wafv2_ip_set" "allowlist" {
  name               = "alb-whitelist-ipset"
  description        = "Allow specific IPs for ALB"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"

  addresses = var.whitelisted_ips

  tags = {
    Name = "ALB Allowlist IPSet"
  }
}

resource "aws_wafv2_web_acl" "alb_waf" {
  name  = "alb-waf-allow-only-ip"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "AllowSpecificIPs"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allowlist.arn
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowSpecificIPs"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "alb-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "ALB-WAF"
  }
}

resource "aws_wafv2_web_acl_association" "alb_waf_assoc" {
  resource_arn = aws_lb.geth_rpc.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}
