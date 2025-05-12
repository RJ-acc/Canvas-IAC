################################################################################
# GP3 Encrypted Storage Class
################################################################################

resource "null_resource" "patch_gp2_default" {
  provisioner "local-exec" {
    command = <<EOT
    kubectl patch storageclass gp2 -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}' || true
    EOT
  }

  depends_on = [module.eks]
}

resource "kubernetes_storage_class" "ebs_csi_encrypted_gp3_storage_class" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "xfs"
    encrypted = true
    type      = "gp3"
  }

  depends_on = [kubernetes_annotations.patch_gp2_default]
}

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

  tags = local.tags
}

################################################################################
# EKS Blueprints Addons
################################################################################

resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_namespace_v1" "istio-ingress" {
  metadata {
    labels = {
      istio-injection = "enabled"
    }
    name = "istio-ingress" # per https://github.com/istio/istio/blob/master/manifests/charts/gateways/istio-ingress/values.yaml#L2
  }
}

module "eks_blueprints_addons" {
  source = "git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons?ref=a9963f4a0e168f73adb033be594ac35868696a91"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  #---------------------------------------
  # Amazon EKS Managed Add-ons
  #---------------------------------------
  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  #---------------------------------------
  # Cert Manager
  #---------------------------------------
  enable_cert_manager = true
  cert_manager = {
    chart_version    = "v1.15.3"
    namespace        = "cert-manager"
    create_namespace = true
  }

  #---------------------------------------
  # AWS Load Balancer Controller
  #---------------------------------------
  enable_aws_load_balancer_controller = true

  #---------------------------------------
  # Istio OSS & ODA Canvas Framework
  #---------------------------------------
  helm_releases = {

    istio-base = {
      chart         = "base"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istio-base"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name
      create_namespace = false
    }

    istiod = {
      chart         = "istiod"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istiod"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name
      create_namespace = false
      set = [
        {
          name  = "meshConfig.accessLogFile"
          value = "/dev/stdout"
        }
      ]
    }

    istio-ingress = {
      chart         = "gateway"
      chart_version = local.istio_chart_version
      repository    = local.istio_chart_url
      name          = "istio-ingress"
      namespace     = kubernetes_namespace_v1.istio-ingress.metadata[0].name
      create_namespace = false
      values = [
        yamlencode(
          {
            labels = {
              istio = "ingressgateway"
              app   = "istio-ingress"
            }
            service = {
              type = "LoadBalancer"
              annotations = {
                "service.beta.kubernetes.io/aws-load-balancer-internal"   = "true"
                "service.beta.kubernetes.io/aws-load-balancer-attributes" = "load_balancing.cross_zone.enabled=true"
              }
            }
          }
        )
      ]
    }

  }

  tags = local.tags
}

################################################################################
# Canvas Installation after all pre-requisites
################################################################################

# Canvas Namespace
resource "kubernetes_namespace_v1" "canvas" {
  metadata {
    name = "canvas"
  }
}

# Canvas Helm Chart Installation
resource "helm_release" "canvas" {
  name       = "canvas"
  chart      = "canvas-oda"
  repository = var.canvas_chart_repo
  namespace  = kubernetes_namespace_v1.canvas.metadata[0].name

  create_namespace = false

  set {
    name  = "canvas-vault.enabled"
    value = false
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}
