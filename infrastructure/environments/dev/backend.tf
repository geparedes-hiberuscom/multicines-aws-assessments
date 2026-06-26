# =============================================================================
# Backend Configuration - Development Environment
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "multicines-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "multicines-terraform-locks"
    encrypt        = true
  }
}
