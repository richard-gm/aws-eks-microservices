output "workload_security_group_id" {
  description = "Security group for cluster workloads / ingress / ArgoCD."
  value       = aws_security_group.workload.id
}

output "cluster_security_group_id" {
  description = "EKS control plane security group."
  value       = var.cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS worker node security group."
  value       = var.node_security_group_id
}
