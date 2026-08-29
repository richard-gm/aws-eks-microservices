# Inputs for the VPC module. Values come from environments/<env>/vpc/terragrunt.hcl.
variable "name" {
  description = "Name prefix for the VPC and its resources."
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to spread subnets across."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (workload) subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public (NAT/ALB) subnets."
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name, used to tag subnets for auto-discovery."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
