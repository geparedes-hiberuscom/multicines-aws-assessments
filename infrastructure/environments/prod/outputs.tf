# =============================================================================
# Outputs - Production Environment
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = "" # module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [] # module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [] # module.networking.private_subnet_ids
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = "" # module.ecs.ecs_cluster_arn
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = "" # module.ecs.ecs_service_name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = "" # module.alb.alb_dns_name
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = "" # module.observability.log_group_name
}
