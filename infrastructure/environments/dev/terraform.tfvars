# =============================================================================
# Variable Values - Development Environment
# =============================================================================

aws_region           = "us-east-1"
environment          = "dev"
vpc_cidr             = "192.168.103.0/24"
vpc_secondary_cidr   = "192.168.104.0/24"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["192.168.103.0/26", "192.168.104.0/26"]
private_subnet_cidrs = ["192.168.103.64/26"]
ecs_cpu              = 256
ecs_memory           = 1024
ecs_desired_count    = 1
log_retention_days   = 30
create_ecs_cluster   = false
ecs_cluster_name     = "multicines-cluster"
ecr_repository_name  = "multicines/integration-service"
container_port       = 8095
container_image_tag  = "latest"
enable_nat_gateway   = true
enable_adot_sidecar  = true
vpn_available        = false
health_check_path    = "/actuator/health"
