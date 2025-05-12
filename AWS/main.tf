data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "ecr"
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
    }
  }
}

locals {
  name   = var.cluster_name
  region = var.aws_region

  cluster_version = var.k8s_version

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  istio_chart_url     = "https://istio-release.storage.googleapis.com/charts"
  istio_chart_version = var.istio_chart_version

  oda_canvas_chart_url = var.canvas_chart_repo

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}
