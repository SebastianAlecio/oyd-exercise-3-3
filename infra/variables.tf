variable "region" {
  description = "AWS region where the EKS cluster will be provisioned"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version for the EKS control plane"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group (must be arm64 for AL2023_ARM_64_STANDARD AMI)"
  type        = string
  default     = "t4g.small"
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
}

variable "node_desired_size" {
  description = "Desired number of nodes in the managed node group"
  type        = number
}
