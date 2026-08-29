# Allow trusted networks to reach the Kubernetes API server.
resource "aws_security_group_rule" "api_ingress" {
  for_each = toset(var.allowed_api_cidrs)

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = var.cluster_security_group_id
  description       = "Kubernetes API access from ${each.value}"
}

# Allow the control plane to reach the Kubelet on worker nodes.
resource "aws_security_group_rule" "node_kubelet_from_control_plane" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = var.cluster_security_group_id
  security_group_id        = var.node_security_group_id
  description              = "Kubelet API from control plane"
}

# Allow metrics-server / webhooks from the control plane to nodes (443).
resource "aws_security_group_rule" "node_https_from_control_plane" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.cluster_security_group_id
  security_group_id        = var.node_security_group_id
  description              = "HTTPS webhooks from control plane"
}

# Workload security group for ingress controllers / ArgoCD server.
resource "aws_security_group" "workload" {
  name        = "${var.cluster_name}-workload"
  description = "Security group for cluster workloads and ingress."
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "HTTP from inside the VPC"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "HTTPS from inside the VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-workload"
  })
}
