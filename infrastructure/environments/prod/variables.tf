# =============================================================================
# Input Variables - Production Environment
# =============================================================================

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC"
  type        = string
}

variable "vpc_secondary_cidr" {
  description = "Secondary CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (/26)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (/26)"
  type        = list(string)
}

variable "ecs_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
}

variable "ecs_memory" {
  description = "Memory in MB for ECS task"
  type        = number
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
}

variable "create_ecs_cluster" {
  description = "Whether to create a new ECS cluster (false = use existing)"
  type        = bool
  default     = false
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "multicines-cluster"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "multicines/integration-service"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8095
}

variable "container_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "enable_nat_gateway" {
  description = "Whether to enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_adot_sidecar" {
  description = "Whether to enable AWS Distro for OpenTelemetry sidecar"
  type        = bool
  default     = true
}

variable "vpn_available" {
  description = "Whether VPN connection is available for on-premise connectivity"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Health check path for the application"
  type        = string
  default     = "/actuator/health"
}
