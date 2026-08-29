module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # EKS requires the cluster tag on subnets for load-balancer auto-discovery.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  # Private subnets host the Karpenter-provisioned nodes and pod ENIs.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    # Karpenter discovers subnets to launch nodes in via this tag.
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}
