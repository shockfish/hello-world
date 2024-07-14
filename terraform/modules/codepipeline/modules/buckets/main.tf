variable "buckets" {
  type = set(string)
}

resource "random_uuid" "codepipeline_bucket_prefix" {}

locals {
  map = {
    for i in var.buckets : i => random_uuid.codepipeline_bucket_prefix.result
  }
}

resource "aws_s3_bucket" "codepipeline" {
  for_each = local.map
  bucket   = "${each.key}-${each.value}"
}

resource "aws_s3_bucket_versioning" "codepipeline" {
  for_each = aws_s3_bucket.codepipeline
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline" {
  for_each = aws_s3_bucket.codepipeline
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "buckets" {
  description = "Output contains map with buckets arns and ids"
  value = {
    for k, v in aws_s3_bucket.codepipeline : k => { arn : v.arn, id : v.id }
  }
}
