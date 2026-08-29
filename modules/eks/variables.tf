# Inputs for the EKS module. VPC outputs come from the VPC module; names/versions from the environment.
variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the cluster into."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS control plane / Fargate / Karpenter nodes."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (used for public load balancers)."
  type        = list(string)
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
