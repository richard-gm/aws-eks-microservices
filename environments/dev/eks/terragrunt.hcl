include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  # Points at the shared EKS module.
  source = "${get_terragrunt_dir()}/../../../modules/eks"
}

# EKS needs the VPC to already exist (it puts the control plane + node SG there).
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  cluster_name                         = include.env.locals.cluster_name
  cluster_version                      = include.env.locals.cluster_version
  vpc_id                               = dependency.vpc.outputs.vpc_id
  private_subnet_ids                   = dependency.vpc.outputs.private_subnets
  public_subnet_ids                    = dependency.vpc.outputs.public_subnets
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # dev-only open API. Restrict in prod.
  tags = {
    Environment = include.env.locals.env
  }
}