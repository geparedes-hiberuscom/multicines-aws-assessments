# =============================================================================
# Backend Configuration - Production Environment
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "multicines-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "multicines-terraform-locks"
    encrypt        = true
  }
}
