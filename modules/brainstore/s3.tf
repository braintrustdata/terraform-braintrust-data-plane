resource "aws_s3_bucket" "brainstore" {
  bucket_prefix = "${var.deployment_name}-brainstore-"

  lifecycle {
    ignore_changes = [
      # S3 does not support renaming buckets
      bucket_prefix
    ]
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "brainstore" {
  bucket = aws_s3_bucket.brainstore.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}
