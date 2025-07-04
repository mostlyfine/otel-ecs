# セキュリティグループ
resource "aws_security_group" "grafana" {
  name_prefix = "${local.name}-grafana-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [module.alb.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "internal_services" {
  name_prefix = "${local.name}-internal-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [module.internal_alb.security_group_id]
  }

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# IAMポリシー：S3アクセス用
resource "aws_iam_policy" "s3_access" {
  name_prefix = "${local.name}-s3-access-"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.name}-mimir-${random_string.bucket_suffix.result}",
          "arn:aws:s3:::${local.name}-mimir-${random_string.bucket_suffix.result}/*",
          "arn:aws:s3:::${local.name}-loki-${random_string.bucket_suffix.result}",
          "arn:aws:s3:::${local.name}-loki-${random_string.bucket_suffix.result}/*",
          "arn:aws:s3:::${local.name}-tempo-${random_string.bucket_suffix.result}",
          "arn:aws:s3:::${local.name}-tempo-${random_string.bucket_suffix.result}/*"
        ]
      }
    ]
  })

  tags = local.tags
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.9.0"

  cluster_name = local.name

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    grafana = {
      cpu    = 256
      memory = 512

      # Container definition
      container_definitions = {
        grafana = {
          image = local.images.grafana
          environment = [
            {
              name  = "GF_SECURITY_ADMIN_PASSWORD"
              value = var.grafana_admin_password
            },
            {
              name  = "GF_INSTALL_PLUGINS"
              value = "grafana-piechart-panel"
            }
          ]
          port_mappings = [
            {
              container_port = 3000
              host_port      = 3000
              protocol       = "tcp"
            }
          ]

          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${local.name}/grafana"
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "ecs"
            }
          }
        }
      }

      load_balancer = {
        grafana = {
          target_group_arn = module.alb.target_groups["grafana"].arn
          container_name   = "grafana"
          container_port   = 3000
        }
      }

      security_group_ids = [aws_security_group.grafana.id]
      subnet_ids         = module.vpc.private_subnets

      create_cloudwatch_log_group = true
      cloudwatch_log_group_name   = "/ecs/${local.name}/grafana"
    }

    mimir = {
      cpu    = 512
      memory = 1024

      container_definitions = {
        mimir = {
          image = local.images.mimir
          command = [
            "-config.file=/etc/mimir/mimir.yaml",
            "-target=all"
          ]
          environment = [
            {
              name  = "MIMIR_S3_BUCKET"
              value = "${local.name}-mimir-${random_string.bucket_suffix.result}"
            }
          ]
          port_mappings = [
            {
              container_port = 8080
              host_port      = 8080
              protocol       = "tcp"
            }
          ]

          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${local.name}/mimir"
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "ecs"
            }
          }
        }
      }

      load_balancer = {
        mimir = {
          target_group_arn = module.internal_alb.target_groups["mimir"].arn
          container_name   = "mimir"
          container_port   = 8080
        }
      }

      security_group_ids = [aws_security_group.internal_services.id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        s3_access = aws_iam_policy.s3_access.arn
      }

      create_cloudwatch_log_group = true
      cloudwatch_log_group_name   = "/ecs/${local.name}/mimir"
    }

    loki = {
      cpu    = 512
      memory = 1024

      container_definitions = {
        loki = {
          image = local.images.loki
          command = [
            "-config.file=/etc/loki/local-config.yaml"
          ]
          environment = [
            {
              name  = "LOKI_S3_BUCKET"
              value = "${local.name}-loki-${random_string.bucket_suffix.result}"
            }
          ]
          port_mappings = [
            {
              container_port = 3100
              host_port      = 3100
              protocol       = "tcp"
            }
          ]

          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${local.name}/loki"
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "ecs"
            }
          }
        }
      }

      load_balancer = {
        loki = {
          target_group_arn = module.internal_alb.target_groups["loki"].arn
          container_name   = "loki"
          container_port   = 3100
        }
      }

      security_group_ids = [aws_security_group.internal_services.id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        s3_access = aws_iam_policy.s3_access.arn
      }

      create_cloudwatch_log_group = true
      cloudwatch_log_group_name   = "/ecs/${local.name}/loki"
    }

    tempo = {
      cpu    = 512
      memory = 1024

      container_definitions = {
        tempo = {
          image = local.images.tempo
          command = [
            "-config.file=/etc/tempo/tempo.yaml"
          ]
          environment = [
            {
              name  = "TEMPO_S3_BUCKET"
              value = "${local.name}-tempo-${random_string.bucket_suffix.result}"
            }
          ]
          port_mappings = [
            {
              container_port = 3200
              host_port      = 3200
              protocol       = "tcp"
            }
          ]

          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${local.name}/tempo"
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "ecs"
            }
          }
        }
      }

      load_balancer = {
        tempo = {
          target_group_arn = module.internal_alb.target_groups["tempo"].arn
          container_name   = "tempo"
          container_port   = 3200
        }
      }

      security_group_ids = [aws_security_group.internal_services.id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        s3_access = aws_iam_policy.s3_access.arn
      }

      create_cloudwatch_log_group = true
      cloudwatch_log_group_name   = "/ecs/${local.name}/tempo"
    }

    otel_collector = {
      cpu    = 256
      memory = 512

      container_definitions = {
        otel_collector = {
          image = local.images.otel_collector
          environment = [
            {
              name  = "LOKI_ENDPOINT"
              value = "http://loki.${local.name}.local:3100/loki/api/v1/push"
            },
            {
              name  = "MIMIR_ENDPOINT"
              value = "http://mimir.${local.name}.local:8080/api/v1/push"
            },
            {
              name  = "TEMPO_ENDPOINT"
              value = "http://tempo.${local.name}.local:3200"
            }
          ]
          port_mappings = [
            {
              container_port = 4317
              host_port      = 4317
              protocol       = "tcp"
            },
            {
              container_port = 4318
              host_port      = 4318
              protocol       = "tcp"
            },
            {
              container_port = 8888
              host_port      = 8888
              protocol       = "tcp"
            }
          ]

          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/${local.name}/otel-collector"
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "ecs"
            }
          }
        }
      }

      load_balancer = {
        otel_collector = {
          target_group_arn = module.internal_alb.target_groups["otel_collector"].arn
          container_name   = "otel_collector"
          container_port   = 4317
        }
      }

      security_group_ids = [aws_security_group.internal_services.id]
      subnet_ids         = module.vpc.private_subnets

      create_cloudwatch_log_group = true
      cloudwatch_log_group_name   = "/ecs/${local.name}/otel-collector"
    }
  }

  tags = local.tags
}
