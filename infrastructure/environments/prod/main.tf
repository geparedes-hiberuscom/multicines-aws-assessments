# =============================================================================
# Main Terraform Configuration - Production Environment
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "multicines"
      Environment = var.environment
      ManagedBy   = "terraform"
      Service     = "api-integration-service"
    }
  }
}

# -----------------------------------------------------------------------------
# Module Instantiation (populated in task 11.1)
# -----------------------------------------------------------------------------
# module "networking" {
#   source = "../../modules/networking"
#   ...
# }
#
# module "security" {
#   source = "../../modules/security"
#   ...
# }
#
# module "observability" {
#   source = "../../modules/observability"
#   ...
# }
#
# module "ssm" {
#   source = "../../modules/ssm"
#   ...
# }
#
# module "ecs" {
#   source = "../../modules/ecs"
#   ...
# }
