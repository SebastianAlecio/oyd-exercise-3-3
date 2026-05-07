module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  # 1. Without this, the IAM user who ran apply has no kubectl access.
  #    update-kubeconfig succeeds but every kubectl call returns 403.
  enable_cluster_creator_admin_permissions = true

  # 2. Without this, EKS extended support billing starts after standard window.
  cluster_upgrade_policy = { support_type = "STANDARD" }

  # Public API endpoint so kubectl from the developer machine can reach it.
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      # 3. Required for t4g (arm64) nodes. Omit -> x86_64 AMI -> exec format error at kubelet.
      ami_type = "AL2023_ARM_64_STANDARD"

      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }
}
