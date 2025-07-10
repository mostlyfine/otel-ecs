
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
          "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-${local.name}-mimir",
          "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-${local.name}-mimir/*",
          "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-${local.name}-loki",
          "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-${local.name}-loki/*",
          "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-${local.name}-tempo",
          "arn:aws:s3:::${data.aws_caller_identity.current.account_id}-${local.name}-tempo/*"
        ]
      }
    ]
  })

  tags = local.tags
}

# IAMポリシー：FireLens用CloudWatch Logsアクセス
resource "aws_iam_policy" "firelens_logs" {
  name_prefix = "${local.name}-firelens-logs-"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

  tags = local.tags
}

# CloudWatch Logsグループ：FireLens用
resource "aws_cloudwatch_log_group" "firelens" {
  name              = "/ecs/${local.name}/firelens"
  retention_in_days = 7

  tags = local.tags
}

# CloudWatch Logsグループ：各アプリケーション用（FireLens経由）
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${local.name}/grafana"
  retention_in_days = 7

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "mimir" {
  name              = "/ecs/${local.name}/mimir"
  retention_in_days = 7

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "loki" {
  name              = "/ecs/${local.name}/loki"
  retention_in_days = 7

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "tempo" {
  name              = "/ecs/${local.name}/tempo"
  retention_in_days = 7

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "otel_collector" {
  name              = "/ecs/${local.name}/otel-collector"
  retention_in_days = 7

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
            log_driver = "awsfirelens"
            options = {
              "Name"              = "cloudwatch_logs"
              "region"            = local.region
              "log_group_name"    = aws_cloudwatch_log_group.grafana.name
              "log_stream_prefix" = "firelens"
            }
          }
        }

        log_router = {
          image = "906394416424.dkr.ecr.${local.region}.amazonaws.com/aws-for-fluent-bit:stable"
          firelens_configuration = {
            type = "fluentbit"
          }
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.firelens.name
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "firelens"
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

      security_group_ids = [module.grafana_sg.security_group_id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        firelens_logs = aws_iam_policy.firelens_logs.arn
      }

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
              value = "${data.aws_caller_identity.current.account_id}-${local.name}-mimir"
            },
            # S3バックエンド設定
            {
              name  = "MIMIR_BLOCKS_STORAGE_BACKEND"
              value = "s3"
            },
            {
              name  = "MIMIR_BLOCKS_STORAGE_S3_BUCKET_NAME"
              value = "${data.aws_caller_identity.current.account_id}-${local.name}-mimir"
            },
            {
              name  = "MIMIR_BLOCKS_STORAGE_S3_REGION"
              value = local.region
            },
            {
              name  = "MIMIR_ALERTMANAGER_STORAGE_BACKEND"
              value = "s3"
            },
            {
              name  = "MIMIR_ALERTMANAGER_STORAGE_S3_BUCKET_NAME"
              value = "${data.aws_caller_identity.current.account_id}-${local.name}-mimir"
            },
            {
              name  = "MIMIR_RULER_STORAGE_BACKEND"
              value = "s3"
            },
            {
              name  = "MIMIR_RULER_STORAGE_S3_BUCKET_NAME"
              value = "${data.aws_caller_identity.current.account_id}-${local.name}-mimir"
            },
            # 10分間の保持設定
            {
              name  = "MIMIR_BLOCKS_STORAGE_TSDB_BLOCK_RANGES_PERIOD"
              value = "10m"
            },
            {
              name  = "MIMIR_BLOCKS_STORAGE_TSDB_RETENTION_PERIOD"
              value = "10m"
            },
            {
              name  = "MIMIR_COMPACTOR_COMPACTION_INTERVAL"
              value = "1m"
            },
            {
              name  = "MIMIR_COMPACTOR_DELETION_DELAY"
              value = "1m"
            },
            # クエリ設定（S3からの読み取り）
            {
              name  = "MIMIR_QUERIER_QUERY_INGESTERS_WITHIN"
              value = "10m"
            },
            {
              name  = "MIMIR_QUERIER_QUERY_STORE_FOR_LABELS_ENABLED"
              value = "true"
            },
            {
              name  = "MIMIR_STORE_GATEWAY_SHARDING_ENABLED"
              value = "true"
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
            log_driver = "awsfirelens"
            options = {
              "Name"              = "cloudwatch_logs"
              "region"            = local.region
              "log_group_name"    = aws_cloudwatch_log_group.mimir.name
              "log_stream_prefix" = "firelens"
            }
          }
        }

        log_router = {
          image = "906394416424.dkr.ecr.${local.region}.amazonaws.com/aws-for-fluent-bit:stable"
          firelens_configuration = {
            type = "fluentbit"
          }
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.firelens.name
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "firelens"
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

      security_group_ids = [module.internal_services_sg.security_group_id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        s3_access     = aws_iam_policy.s3_access.arn
        firelens_logs = aws_iam_policy.firelens_logs.arn
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
              value = "${data.aws_caller_identity.current.account_id}-${local.name}-loki"
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
            log_driver = "awsfirelens"
            options = {
              "Name"              = "cloudwatch_logs"
              "region"            = local.region
              "log_group_name"    = aws_cloudwatch_log_group.loki.name
              "log_stream_prefix" = "firelens"
            }
          }
        }

        log_router = {
          image = "906394416424.dkr.ecr.${local.region}.amazonaws.com/aws-for-fluent-bit:stable"
          firelens_configuration = {
            type = "fluentbit"
          }
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.firelens.name
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "firelens"
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

      security_group_ids = [module.internal_services_sg.security_group_id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        s3_access     = aws_iam_policy.s3_access.arn
        firelens_logs = aws_iam_policy.firelens_logs.arn
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
              value = "${data.aws_caller_identity.current.account_id}-${local.name}-tempo"
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
            log_driver = "awsfirelens"
            options = {
              "Name"              = "cloudwatch_logs"
              "region"            = local.region
              "log_group_name"    = aws_cloudwatch_log_group.tempo.name
              "log_stream_prefix" = "firelens"
            }
          }
        }

        log_router = {
          image = "906394416424.dkr.ecr.${local.region}.amazonaws.com/aws-for-fluent-bit:stable"
          firelens_configuration = {
            type = "fluentbit"
          }
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.firelens.name
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "firelens"
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

      security_group_ids = [module.internal_services_sg.security_group_id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        s3_access     = aws_iam_policy.s3_access.arn
        firelens_logs = aws_iam_policy.firelens_logs.arn
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
            log_driver = "awsfirelens"
            options = {
              "Name"              = "cloudwatch_logs"
              "region"            = local.region
              "log_group_name"    = aws_cloudwatch_log_group.otel_collector.name
              "log_stream_prefix" = "firelens"
            }
          }
        }

        log_router = {
          image = "906394416424.dkr.ecr.${local.region}.amazonaws.com/aws-for-fluent-bit:stable"
          firelens_configuration = {
            type = "fluentbit"
          }
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.firelens.name
              "awslogs-region"        = local.region
              "awslogs-stream-prefix" = "firelens"
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

      security_group_ids = [module.internal_services_sg.security_group_id]
      subnet_ids         = module.vpc.private_subnets

      task_role_policies = {
        firelens_logs = aws_iam_policy.firelens_logs.arn
      }

      create_cloudwatch_log_group = true
      cloudwatch_log_group_name   = "/ecs/${local.name}/otel-collector"
    }
  }

  tags = local.tags
}
