# VPC unit. Merges two flat partials: root.hcl (remote_state + gates) and
# env.hcl (locals + AWS provider). Values are pulled from the exposed env
# include so they live in one place (environments/dev/env.hcl).
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  # Shared VPC module; this unit only supplies inputs.
  source = "${get_terragrunt_dir()}/../../../modules/vpc"
}

locals {
  name                 = "eks-${include.env.locals.env}-vpc"
  cidr                 = include.env.locals.vpc_cidr
  availability_zones   = include.env.locals.availability_zones
  private_subnet_cidrs = include.env.locals.private_subnet_cidrs
  public_subnet_cidrs  = include.env.locals.public_subnet_cidrs
  cluster_name         = include.env.locals.cluster_name
  env                  = include.env.locals.env
}

inputs = {
  name                 = local.name
  cidr                 = local.cidr
  availability_zones   = local.availability_zones
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs
  cluster_name         = local.cluster_name
  tags = {
    Environment = local.env
  }
}