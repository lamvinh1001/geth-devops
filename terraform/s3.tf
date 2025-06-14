module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.project_name}-bucket"

  versioning = {
    enabled = true
  }
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-bucket"
  })
}
