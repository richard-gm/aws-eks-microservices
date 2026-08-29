# -----------------------------------------------------------------------------
# EKS control plane
# -----------------------------------------------------------------------------
# We use the official AWS "eks" Terraform module (v20). It creates the managed
# Kubernetes control plane, the OIDC provider (for IRSA), and the cluster/node
# security groups. We deliberately do NOT create managed node groups — Karpenter
# (a separate module) provisions the EC2 worker nodes on demand.
# -----------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Public API endpoint is convenient for dev; restrict via CIDRs. For prod
  # consider setting cluster_endpoint_public_access = false and using a bastion.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # IRSA is required for Karpenter and ArgoCD service accounts.
  enable_irsa = true

  # We do not use EKS-managed node groups: Karpenter provisions capacity.
  # A node security group is still created so Karpenter/security-groups can
  # reference it for the nodes it launches.
  create_node_security_group = true
  eks_managed_node_groups    = {}

  # Bootstrap Karpenter + core addons on Fargate so they have a place to run
  # before Karpenter provisions any EC2 capacity.
  fargate_profiles = {
    kube_system = {
      selectors = [{ namespace = "kube-system" }]
    }
    karpenter = {
      selectors = [{ namespace = "karpenter" }]
    }
  }

  tags = var.tags
}

# Expose the OIDC provider so other modules can create IRSA roles.
data "aws_iam_openid_connect_provider" "oidc" {
  arn = module.eks.oidc_provider_arn
}
