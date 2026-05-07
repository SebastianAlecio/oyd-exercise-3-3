output "cluster_name" {
  description = "Name of the EKS cluster (used to generate kubeconfig)"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data required to authenticate kubectl"
  value       = module.eks.cluster_certificate_authority_data
}
