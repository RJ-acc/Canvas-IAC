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


  #---------------------------------------
  # Cert Manager
  #---------------------------------------
  enable_cert_manager = false
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
