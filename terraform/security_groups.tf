# Grafana用セキュリティグループ
module "grafana_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"

  name        = "${local.name}-grafana"
  description = "Security group for Grafana service"
  vpc_id      = module.vpc.vpc_id

  # ALBからのHTTPアクセスを許可
  ingress_with_source_security_group_id = [
    {
      from_port                = 3000
      to_port                  = 3000
      protocol                 = "tcp"
      description              = "Allow HTTP from ALB"
      source_security_group_id = module.alb.security_group_id
    }
  ]

  # すべてのアウトバウンドトラフィックを許可
  egress_rules = ["all-all"]

  tags = local.tags
}

# 内部サービス用セキュリティグループ
module "internal_services_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"

  name        = "${local.name}-internal-services"
  description = "Security group for internal services (Mimir, Loki, Tempo, OpenTelemetry Collector)"
  vpc_id      = module.vpc.vpc_id

  # 内部ALBからのアクセスを許可
  ingress_with_source_security_group_id = [
    {
      from_port                = 0
      to_port                  = 65535
      protocol                 = "tcp"
      description              = "Allow traffic from internal ALB"
      source_security_group_id = module.internal_alb.security_group_id
    }
  ]

  # セキュリティグループ内での通信を許可
  ingress_with_self = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      description = "Allow communication within security group"
    }
  ]

  # すべてのアウトバウンドトラフィックを許可
  egress_rules = ["all-all"]

  tags = local.tags
}
