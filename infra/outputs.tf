output "cluster_name" {
  description = "Name of the EKS cluster (used for aws eks update-kubeconfig)"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint URL"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
}
