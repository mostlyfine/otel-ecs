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

  # S3バケット名のプレフィックス（random_stringと組み合わせて一意性を確保）
  s3_bucket_names = {
    mimir = "${local.name}-mimir"
    loki  = "${local.name}-loki"
    tempo = "${local.name}-tempo"
  }
}
