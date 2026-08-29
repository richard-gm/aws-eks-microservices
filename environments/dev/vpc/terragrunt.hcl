# VPC unit. Inherits remote_state + provider from root.
include {
  path = find_in_parent_folders()
}

terraform {
  # Shared VPC module; this unit only supplies inputs.
  source = "${get_terragrunt_dir()}/../../../modules/vpc"
}

# Inputs reference shared locals so values live in one place (environments/dev).
inputs = {
  name                 = "eks-${local.env}-vpc"
  cidr                 = local.vpc_cidr
  availability_zones   = local.availability_zones
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs
  cluster_name         = local.cluster_name
  tags = {
    Environment = local.env
  }
}
