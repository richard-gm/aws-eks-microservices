# Inputs for the security-groups module. The cluster/node SG ids come from the EKS module.
variable "vpc_id" {
  description = "ID of the VPC the security groups live in."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (used for naming/tagging)."
  type        = string
}

variable "cluster_security_group_id" {
  description = "Security group of the EKS control plane."
  type        = string
}

variable "node_security_group_id" {
  description = "Security group of the EKS worker nodes."
  type        = string
}

variable "allowed_api_cidrs" {
  description = "CIDR blocks permitted to reach the Kubernetes API server (443)."
  type        = list(string)
  default     = []
}

variable "vpc_cidr_block" {
  description = "VPC CIDR, used to scope intra-cluster traffic."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
