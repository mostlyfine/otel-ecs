output "grafana_url" {
  description = "The URL of the Grafana UI"
  value       = "http://${module.alb.dns_name}"
}

output "internal_alb_dns" {
  description = "The DNS name of the internal ALB for service communication"
  value       = module.internal_alb.dns_name
}

output "vpc_id" {
  description = "The VPC ID where all resources are deployed"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "The private subnet IDs where ECS services are deployed"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "The public subnet IDs where ALB is deployed"
  value       = module.vpc.public_subnets
}

output "s3_buckets" {
  description = "S3 bucket names for observability data storage"
  value = {
    mimir = module.s3_bucket_mimir.s3_bucket_id
    loki  = module.s3_bucket_loki.s3_bucket_id
    tempo = module.s3_bucket_tempo.s3_bucket_id
  }
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}
