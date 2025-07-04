module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.7.0"

  name = local.name

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Allow HTTPS traffic for Grafana access
  security_group_ingress_rules = {
    all_https = {
      from_port = 443
      to_port   = 443
      protocol  = "tcp"
      cidr_ipv4 = "0.0.0.0/0"
    }
    all_http = {
      from_port = 80
      to_port   = 80
      protocol  = "tcp"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      protocol  = "-1"
      from_port = 0
      to_port   = 0
      cidr_ipv4 = "0.0.0.0/0"
    }
  }

  target_groups = {
    grafana = {
      name_prefix       = "graf-"
      backend_protocol  = "HTTP"
      backend_port      = 3000
      target_type       = "ip"
      create_attachment = false
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/login"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "grafana"
      }
    }
  }

  tags = local.tags
}

module "internal_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.7.0"

  name               = "${local.name}-internal"
  internal           = true
  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets

  # Security group will be created and attached to the services
  create_security_group = true
  security_group_ingress_rules = {
    # Allow all traffic from within the VPC
    all_from_vpc = {
      from_port = 0
      to_port   = 0
      protocol  = "-1"
      cidr_ipv4 = module.vpc.vpc_cidr_block
    }
  }
  security_group_egress_rules = {
    all = {
      from_port = 0
      to_port   = 0
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }

  target_groups = {
    mimir = {
      name_prefix       = "mimir"
      backend_protocol  = "HTTP"
      backend_port      = 8080
      target_type       = "ip"
      create_attachment = false
    },
    loki = {
      name_prefix       = "loki"
      backend_protocol  = "HTTP"
      backend_port      = 3100
      target_type       = "ip"
      create_attachment = false
    },
    tempo = {
      name_prefix       = "tempo"
      backend_protocol  = "HTTP"
      backend_port      = 3200
      target_type       = "ip"
      create_attachment = false
    },
    otel_collector = {
      name_prefix       = "otel"
      backend_protocol  = "HTTP"
      backend_port      = 4317
      target_type       = "ip"
      create_attachment = false
    }
  }

  listeners = {
    mimir = {
      port     = 8080
      protocol = "HTTP"
      forward = {
        target_group_key = "mimir"
      }
    },
    loki = {
      port     = 3100
      protocol = "HTTP"
      forward = {
        target_group_key = "loki"
      }
    },
    tempo = {
      port     = 3200
      protocol = "HTTP"
      forward = {
        target_group_key = "tempo"
      }
    },
    otel_collector = {
      port     = 4317
      protocol = "HTTP"
      forward = {
        target_group_key = "otel_collector"
      }
    }
  }

  tags = local.tags
}
