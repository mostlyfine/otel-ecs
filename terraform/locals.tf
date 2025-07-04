locals {
  name   = "otel-ecs"
  region = "ap-northeast-1"

  tags = {
    Project     = local.name
    Environment = "development"
    ManagedBy   = "terraform"
  }

  images = {
    grafana        = "grafana/grafana:11.0.0"
    mimir          = "grafana/mimir:2.11.0"
    loki           = "grafana/loki:2.9.0"
    tempo          = "grafana/tempo:2.3.1"
    otel_collector = "otel/opentelemetry-collector-contrib:0.98.0"
  }

  # S3バケット名（AWS Account IDをprefixとして一意性を確保）
  s3_bucket_names = {
    mimir = "${data.aws_caller_identity.current.account_id}-${local.name}-mimir"
    loki  = "${data.aws_caller_identity.current.account_id}-${local.name}-loki"
    tempo = "${data.aws_caller_identity.current.account_id}-${local.name}-tempo"
  }
}
