module "s3_bucket_loki" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"

  bucket = "${data.aws_caller_identity.current.account_id}-${local.name}-loki"

  # Enable versioning
  versioning = {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Lifecycle configuration
  lifecycle_rule = [
    {
      id     = "loki_data_lifecycle"
      status = "Enabled"
      expiration = {
        days = 90
      }
    }
  ]

  tags = local.tags
}

module "s3_bucket_mimir" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"

  bucket = "${data.aws_caller_identity.current.account_id}-${local.name}-mimir"

  # Enable versioning
  versioning = {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Transfer Acceleration for better performance
  acceleration_status = "Enabled"

  # Lifecycle configuration optimized for metrics data
  lifecycle_rule = [
    {
      id     = "mimir_metrics_lifecycle"
      status = "Enabled"

      # Transition to IA after 30 days
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]

      # Delete after 1 year
      expiration = {
        days = 365
      }
    },
    {
      id                                     = "abort_incomplete_multipart_upload"
      status                                 = "Enabled"
      abort_incomplete_multipart_upload_days = 7
    }
  ]

  tags = local.tags
}

module "s3_bucket_tempo" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"

  bucket = "${data.aws_caller_identity.current.account_id}-${local.name}-tempo"

  # Enable versioning
  versioning = {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Lifecycle configuration
  lifecycle_rule = [
    {
      id     = "tempo_data_lifecycle"
      status = "Enabled"
      expiration = {
        days = 30
      }
    }
  ]

  tags = local.tags
}
