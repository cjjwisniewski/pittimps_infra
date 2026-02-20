locals {
  region         = "eastus2"
  domain_name    = "pittimps.com"
  project_prefix = "pittimps"
  github_repo    = "cjjwisniewski/pittimps.com"
  tags = {
    Project     = "pittimps"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
