module "s3_bucket_loki" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"

  bucket = "${local.name}-loki-${random_string.bucket_suffix.result}"

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

  bucket = "${local.name}-mimir-${random_string.bucket_suffix.result}"

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
      id     = "mimir_data_lifecycle"
      status = "Enabled"
      expiration = {
        days = 365
      }
    }
  ]

  tags = local.tags
}

module "s3_bucket_tempo" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"

  bucket = "${local.name}-tempo-${random_string.bucket_suffix.result}"

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

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
