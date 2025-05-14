################################################################################
# IRSA for EBS CSI Driver
################################################################################

module "ebs_csi_driver_irsa" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=89fe17a6549728f1dc7e7a8f7b707486dfb45d89"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}


module "eks_blueprints_addons" {
  source = "git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons?ref=a9963f4a0e168f73adb033be594ac35868696a91"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns     = { most_recent = true }
    vpc-cni     = { most_recent = true }
    kube-proxy  = { most_recent = true }
  }
}

################################################################################
# Export everything for the second workspace 
################################################################################
output "eks" {
  value = {
    name        = module.eks.cluster_name
    endpoint    = module.eks.cluster_endpoint
    ca_data     = module.eks.cluster_certificate_authority_data
  }
}
