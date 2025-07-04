module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = [for k, v in data.aws_availability_zones.available.names : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in data.aws_availability_zones.available.names : cidrsubnet(var.vpc_cidr, 8, k + 3)]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true

  tags = local.tags
}
