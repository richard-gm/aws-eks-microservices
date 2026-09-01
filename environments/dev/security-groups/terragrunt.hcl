include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  # Shared security-groups module.
  source = "${get_terragrunt_dir()}/../../../modules/security-groups"
}

# Depends on vpc + eks outputs; Terragrunt applies them first.
dependency "vpc" {
  config_path = "../vpc"
}

dependency "eks" {
  config_path = "../eks"
}

# Wire vpc/eks outputs into the module as inputs.
inputs = {
  vpc_id                    = dependency.vpc.outputs.vpc_id
  cluster_name              = dependency.eks.outputs.cluster_name
  cluster_security_group_id = dependency.eks.outputs.cluster_security_group_id
  node_security_group_id    = dependency.eks.outputs.node_security_group_id
  allowed_api_cidrs         = ["0.0.0.0/0"] # dev-only: open API access. Tighten for prod.
  vpc_cidr_block            = dependency.vpc.outputs.vpc_cidr_block
  tags = {
    Environment = include.env.locals.env
  }
}