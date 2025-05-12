module "eks" {
    source          = "terraform-aws-modules/eks/aws"
    version         = "~> 20.31"
    cluster_name    = var.cluster_name
    cluster_version = var.k8s_version
    vpc_id          = module.vpc.vpc_id
    subnet_ids      = module.vpc.private_subnet
    cluster_endpoint_public_access = false
    enable_irsa = true

    tags = {
    cluster = "telco-demo1"
  }

    eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    instance_types         = ["t3.medium"]
    vpc_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  }

    eks_managed_node_groups = {

    node_group = {
      name         = var.cluster_name
      min_size     = 1
      max_size     = 2
      desired_size = 1

    tags = {
        Name = "aws-canvas-nodes"
      }
    }
  }

  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
    node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15021 = {
      description                   = "Cluster API to nodes ports/protocols as present in values file of Istio ingress"
      protocol                      = "TCP"
      from_port                     = 15021
      to_port                       = 15021
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

}