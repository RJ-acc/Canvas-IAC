################################################################################
# GP3 Encrypted Storage Class
################################################################################

resource "null_resource" "patch_gp2_default" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Patching gp2 StorageClass (if it exists)…"
      kubectl patch storageclass gp2 \
        --type merge \
        -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || true
    EOT
  }
  depends_on = [module.eks]
}

resource "kubernetes_storage_class" "gp3_encrypted" {
  metadata {
    name = "gp3"
    annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "xfs"
    encrypted = "true"
    type      = "gp3"
  }

  depends_on = [null_resource.patch_gp2_default]
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



################################################################################
# ❷  EKS Blueprints Add-ons  (wrap everything in a module block)
################################################################################
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.18"                               

  #
  # Mandatory wiring back to your cluster/VPC modules
  #
  cluster_name              = module.eks.cluster_name
  cluster_endpoint          = module.eks.cluster_endpoint
  cluster_version           = module.eks.cluster_version
  oidc_provider_arn         = module.eks.oidc_provider_arn

  #
  #  Add-on toggles / parameters
  #
  enable_cert_manager = false                       # each matches a real input var :contentReference[oaicite:1]{index=1}
  cert_manager = {
    chart_version    = "v1.15.3"
    namespace        = "cert-manager"
    create_namespace = true
  }

  enable_aws_load_balancer_controller = true

  # Helm charts you want the module to install for you
  helm_releases = {

    istio-base = {
      chart            = "base"
      chart_version    = local.istio_chart_version
      repository       = local.istio_chart_url
      name             = "istio-base"
      namespace        = kubernetes_namespace_v1.istio_system.metadata[0].name
      create_namespace = false
    }

    istiod = {
      chart            = "istiod"
      chart_version    = local.istio_chart_version
      repository       = local.istio_chart_url
      name             = "istiod"
      namespace        = kubernetes_namespace_v1.istio_system.metadata[0].name
      create_namespace = false
      set = [{
        name  = "meshConfig.accessLogFile"
        value = "/dev/stdout"
      }]
    }

    istio-ingress = {
      chart            = "gateway"
      chart_version    = local.istio_chart_version
      repository       = local.istio_chart_url
      name             = "istio-ingress"
      namespace        = kubernetes_namespace_v1.istio_ingress.metadata[0].name
      create_namespace = false
      values = [yamlencode({
        labels   = { istio = "ingressgateway", app = "istio-ingress" }
        service  = {
          type        = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-internal"   = "true"
            "service.beta.kubernetes.io/aws-load-balancer-attributes" = "load_balancing.cross_zone.enabled=true"
          }
        }
      })]
    }
  }

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


# Locals for canvas  helm  chart 
locals {
  enable_istio  = var.gateway_type == "istio"
  enable_apisix = var.gateway_type == "apisix"
  enable_kong   = var.gateway_type == "kong"
}

# Canvas Helm Chart Installation
resource "helm_release" "canvas" {
  name       = "canvas"
  chart      = "canvas-oda"
  repository = var.canvas_chart_repo
  namespace  = kubernetes_namespace_v1.canvas.metadata[0].name
  create_namespace = false

  # canvas-vault
  set {
    name  = "canvas-vault.enabled"
    value = var.canvas_vault_enabled ? "true" : "false"
  }

  # For Gateways – only ONE will evaluate to "true"
  set {
    name  = "api-operator-istio.enabled"
    value = local.enable_istio ? "true" : "false"
  }

  set {
    name  = "apisix-gateway-install.enabled"
    value = local.enable_apisix ? "true" : "false"
  }

  set {
    name  = "kong-gateway-install.enabled"
    value = local.enable_kong ? "true" : "false"
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}
